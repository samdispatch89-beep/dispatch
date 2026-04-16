const functions = require("firebase-functions");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const PDFDocument = require("pdfkit");
const {S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand} = require("@aws-sdk/client-s3");
const {getSignedUrl} = require("@aws-sdk/s3-request-presigner");
const fs = require("fs");
const os = require("os");
const path = require("path");

admin.initializeApp();

const db = admin.database();
const VALID_DOCUMENT_TYPES = new Set([
  "rate_confirmation",
  "bol",
  "pod",
  "invoice",
  "carrier_packet",
  "invoice_copy",
  "payment_support_document",
  "other",
]);

function getR2Config() {
  const config = functions.config().r2 || {};
  const accountId = String(config.account_id || "").trim();
  const accessKeyId = String(config.access_key || "").trim();
  const secretAccessKey = String(config.secret_key || "").trim();
  const bucketName = String(config.bucket || "").trim();
  if (!accountId || !accessKeyId || !secretAccessKey || !bucketName) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "R2 config is incomplete. Required config keys: r2.account_id, r2.access_key, r2.secret_key, r2.bucket.",
    );
  }
  return {
    accountId,
    accessKeyId,
    secretAccessKey,
    bucketName,
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  };
}

function createR2Client() {
  const config = getR2Config();
  return new S3Client({
    region: "auto",
    endpoint: config.endpoint,
    credentials: {
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
    },
  });
}

function buildR2ObjectPath({
  companyName,
  driverName,
  yearWeek,
  loadNumber,
  documentType,
  fileName,
}) {
  return [
    "companies",
    normalizeStorageSegment(companyName, "company"),
    "drivers",
    normalizeStorageSegment(driverName, "driver"),
    normalizeStorageSegment(yearWeek, "week"),
    "loads",
    normalizeStorageSegment(loadNumber, "load"),
    normalizeStorageSegment(documentType, "document"),
    normalizeStorageSegment(fileName, "file"),
  ].join("/");
}

function buildInvoiceStoragePath(companyName, yearWeek) {
  return [
    "invoices",
    normalizeStorageSegment(companyName, "company"),
    normalizeStorageSegment(yearWeek, "week"),
    `invoice_${Date.now()}.pdf`,
  ].join("/");
}

function toHttpsStorageError(error, fallbackMessage) {
  if (error instanceof functions.https.HttpsError) {
    return error;
  }
  const rawMessage = String(error?.message || error || fallbackMessage);
  logger.error(fallbackMessage, {
    error: rawMessage,
    stack: error?.stack || null,
  });
  return new functions.https.HttpsError("internal", "Upload failed", {
    message: rawMessage,
  });
}

function validateUploadPayload(data) {
  const companyName = String(data.companyName || "").trim();
  const driverName = String(data.driverName || "").trim();
  const yearWeek = String(data.yearWeek || "").trim();
  const loadNumber = String(data.loadNumber || "").trim();
  const documentType = String(data.documentType || "").trim().toLowerCase();
  const fileName = String(data.fileName || "").trim();
  const mimeType = String(data.mimeType || "").trim();
  if (!companyName || !driverName || !yearWeek || !loadNumber || !documentType || !fileName || !mimeType) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "companyName, driverName, yearWeek, loadNumber, documentType, fileName, and mimeType are required.",
    );
  }
  if (!VALID_DOCUMENT_TYPES.has(documentType)) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        `Invalid documentType: ${documentType}`,
    );
  }
  return {
    companyName,
    driverName,
    yearWeek,
    loadNumber,
    documentType,
    fileName,
    mimeType,
  };
}

async function createR2DownloadUrl(storagePath, {
  inline = true,
  fileName = "",
  expiresIn = 15 * 60,
} = {}) {
  const client = createR2Client();
  const config = getR2Config();
  const responseDisposition = inline ?
    "inline" :
    `attachment${fileName ? `; filename="${fileName.replace(/"/g, "")}"` : ""}`;
  return getSignedUrl(client, new GetObjectCommand({
    Bucket: config.bucketName,
    Key: storagePath,
    ResponseContentDisposition: responseDisposition,
  }), {expiresIn});
}

async function createR2UploadUrl(storagePath, {
  contentType = "application/octet-stream",
  expiresIn = 15 * 60,
} = {}) {
  const client = createR2Client();
  const config = getR2Config();
  return getSignedUrl(client, new PutObjectCommand({
    Bucket: config.bucketName,
    Key: storagePath,
    ContentType: contentType,
  }), {expiresIn});
}

async function storeBufferInR2({
  storagePath,
  body,
  contentType,
}) {
  const client = createR2Client();
  const config = getR2Config();
  await client.send(new PutObjectCommand({
    Bucket: config.bucketName,
    Key: storagePath,
    Body: body,
    ContentType: contentType,
  }));
}

function buildInvoiceNumber(invoices) {
  let max = 1000;
  for (const invoice of Object.values(invoices || {})) {
    const match = String(invoice.invoiceNumber || "").match(/(\d+)$/);
    const value = match ? Number(match[1]) : null;
    if (value && value > max) {
      max = value;
    }
  }
  return `INV-${max + 1}`;
}

function normalizeStorageSegment(value, fallback) {
  return String(value || fallback)
      .trim()
      .replace(/[.#$/[\]]+/g, "_")
      .replace(/\s+/g, "_");
}

function isoWeekParts(date) {
  const normalized = new Date(Date.UTC(
      date.getUTCFullYear(),
      date.getUTCMonth(),
      date.getUTCDate(),
  ));
  const weekday = normalized.getUTCDay() === 0 ? 7 : normalized.getUTCDay();
  normalized.setUTCDate(normalized.getUTCDate() + 4 - weekday);
  const year = normalized.getUTCFullYear();
  const start = new Date(Date.UTC(year, 0, 1));
  const week = Math.ceil((((normalized - start) / 86400000) + 1) / 7);
  return {
    year,
    week,
    yearWeek: `${year}-W${String(week).padStart(2, "0")}`,
  };
}

function parseDateValue(value) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function formatDateValue(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toISOString().slice(0, 10);
}

function buildInvoiceDedupeKey({companyId, startDate, endDate, driverIds}) {
  const driverKey = [...driverIds].sort().join("_");
  return [companyId, startDate, endDate, driverKey].join("__");
}

function selectInvoiceStatus(load) {
  if (load.paymentStatus === "Paid") return "Paid";
  if (load.financialStatus === "Invoice Sent" || load.invoiceStatus === "Invoice Sent") {
    return "Invoice Sent";
  }
  return load.operationalStatus || "Delivered";
}

function summarizeLoads(loads) {
  return {
    totalLoads: loads.length,
    totalGross: loads.reduce((sum, load) => sum + Number(load.loadRate || 0), 0),
    totalDispatchFee: loads.reduce((sum, load) => sum + Number(load.dispatchFeeAmount || 0), 0),
    totalRevenue: loads.reduce((sum, load) => sum + Number(load.dispatcherRevenue || 0), 0),
    deliveredLoads: loads.filter((load) => load.operationalStatus === "Delivered").length,
    updatedAt: new Date().toISOString(),
  };
}

async function addActivityLog({
  loadId,
  type,
  message,
  actorId = "",
  actorName = "System",
}) {
  const ref = db.ref("activity_logs").push();
  await ref.set({
    loadId,
    type,
    message,
    actorId,
    actorName,
    createdAt: new Date().toISOString(),
  });
}

async function createNotification({
  userId,
  title,
  message,
  loadId,
  type,
}) {
  const ref = db.ref("notifications").push();
  await ref.set({
    userId,
    title,
    message,
    loadId,
    type,
    read: false,
    createdAt: new Date().toISOString(),
  });
}

async function rebuildWeeklySummariesForLoad(load) {
  if (!load || !load.yearWeek) return;

  const loadsSnap = await db.ref("loads").get();
  const allLoads = Object.entries(loadsSnap.val() || {}).map(([id, value]) => ({
    id,
    ...value,
  }));
  const weekLoads = allLoads.filter((item) => item.yearWeek === load.yearWeek);

  const dispatcherLoads = weekLoads.filter((item) => item.dispatcherId === load.dispatcherId);
  const driverLoads = weekLoads.filter((item) => item.driverId === load.driverId);
  const companyLoads = weekLoads.filter((item) => item.companyId === load.companyId);

  await Promise.all([
    db.ref(`weekly_summaries/dispatchers/${load.dispatcherId}/${load.yearWeek}`).set({
      dispatcherId: load.dispatcherId,
      dispatcherName: load.dispatcherName || "",
      yearWeek: load.yearWeek,
      ...summarizeLoads(dispatcherLoads),
    }),
    db.ref(`weekly_summaries/drivers/${load.driverId}/${load.yearWeek}`).set({
      driverId: load.driverId,
      driverName: load.driverName || "",
      yearWeek: load.yearWeek,
      ...summarizeLoads(driverLoads),
    }),
    db.ref(`weekly_summaries/companies/${load.companyId}/${load.yearWeek}`).set({
      companyId: load.companyId,
      companyName: load.companyName || "",
      yearWeek: load.yearWeek,
      ...summarizeLoads(companyLoads),
    }),
  ]);
}

function drawInvoiceTemplatePage({
  doc,
  invoiceDate,
  closingRate,
  companyName,
  agentName,
  rows,
  pageIndex,
  pageCount,
  summary,
}) {
  const pageWidth = doc.page.width;
  const left = 56;
  const right = pageWidth - 56;
  const usableWidth = right - left;
  const tableTop = 190;
  const tableRowHeight = 34;
  const headerHeight = 42;
  const maxRows = 11;

  doc.font("Helvetica-Bold").fontSize(34).fillColor("#000000").text("Invoice", left, 28);
  doc.font("Helvetica").fontSize(22).text("Customer Weekly Report", left, 68);

  doc.fontSize(18).text("Date:", left, 112);
  doc.moveTo(left + 80, 132).lineTo(left + 340, 132).stroke("#000000");
  doc.text(invoiceDate, left + 88, 109, {width: 210});

  doc.text("Closing Rate:", left + 470, 112);
  doc.moveTo(left + 650, 132).lineTo(right, 132).stroke("#000000");
  doc.text(closingRate, left + 660, 109, {width: right - (left + 660), align: "left"});

  doc.moveTo(left, 150).lineTo(right, 150).stroke("#000000");

  const infoTop = 175;
  const labelWidth = 140;
  const carrierBoxWidth = 430;
  const agentBoxWidth = usableWidth - carrierBoxWidth - 24;

  doc.rect(left, infoTop, labelWidth, 44).fill("#1D1D1D");
  doc.font("Helvetica-Bold").fontSize(20).fillColor("#FFFFFF")
      .text("Carrier", left, infoTop + 12, {width: labelWidth, align: "center"});
  doc.rect(left + labelWidth, infoTop, carrierBoxWidth - labelWidth, 44).stroke("#000000");
  doc.font("Helvetica").fontSize(17).fillColor("#000000")
      .text(companyName, left + labelWidth + 12, infoTop + 12, {
        width: carrierBoxWidth - labelWidth - 24,
      });

  const agentLeft = left + carrierBoxWidth + 24;
  const agentLabelWidth = 140;
  doc.rect(agentLeft, infoTop, agentLabelWidth, 44).fill("#1D1D1D");
  doc.font("Helvetica-Bold").fontSize(20).fillColor("#FFFFFF")
      .text("Agent", agentLeft, infoTop + 12, {width: agentLabelWidth, align: "center"});
  doc.rect(agentLeft + agentLabelWidth, infoTop, agentBoxWidth - agentLabelWidth, 44).stroke("#000000");
  doc.font("Helvetica").fontSize(17).fillColor("#000000")
      .text(agentName, agentLeft + agentLabelWidth + 12, infoTop + 12, {
        width: agentBoxWidth - agentLabelWidth - 24,
      });

  const colWidths = [120, 285, 145, 125, 135];
  const columns = ["Load #", "Load Details", "Duration", "Amount", "Status"];
  let cursorX = left;

  doc.rect(left, tableTop, usableWidth, headerHeight).fill("#1D1D1D");
  doc.font("Helvetica-Bold").fontSize(18).fillColor("#FFFFFF");
  columns.forEach((title, index) => {
    const width = colWidths[index];
    doc.text(title, cursorX, tableTop + 12, {width, align: "center"});
    if (index < columns.length - 1) {
      doc.moveTo(cursorX + width, tableTop).lineTo(cursorX + width, tableTop + headerHeight)
          .strokeColor("#FFFFFF").stroke();
    }
    cursorX += width;
  });

  doc.strokeColor("#000000");
  for (let i = 0; i < maxRows; i++) {
    const y = tableTop + headerHeight + i * tableRowHeight;
    let x = left;
    for (let col = 0; col < colWidths.length; col++) {
      doc.rect(x, y, colWidths[col], tableRowHeight).stroke();
      x += colWidths[col];
    }
  }

  doc.font("Helvetica").fontSize(12).fillColor("#000000");
  rows.forEach((row, index) => {
    const y = tableTop + headerHeight + index * tableRowHeight + 8;
    doc.text(row.loadNumber, left + 8, y, {width: colWidths[0] - 16, align: "left"});
    doc.text(row.details, left + colWidths[0] + 8, y, {width: colWidths[1] - 16});
    doc.text(row.duration, left + colWidths[0] + colWidths[1] + 8, y, {
      width: colWidths[2] - 16,
      align: "center",
    });
    doc.text(row.amount, left + colWidths[0] + colWidths[1] + colWidths[2] + 8, y, {
      width: colWidths[3] - 16,
      align: "right",
    });
    doc.text(row.status, left + colWidths[0] + colWidths[1] + colWidths[2] + colWidths[3] + 8, y, {
      width: colWidths[4] - 16,
      align: "center",
    });
  });

  const summaryTop = tableTop + headerHeight + maxRows * tableRowHeight + 20;
  doc.font("Helvetica-Bold").fontSize(12)
      .text(`Loads: ${summary.totalLoads}`, right - 240, summaryTop, {width: 240, align: "right"})
      .text(`Gross: $${summary.totalGross.toFixed(2)}`, right - 240, summaryTop + 16, {width: 240, align: "right"})
      .text(`Dispatch Fee: $${summary.totalDispatchFee.toFixed(2)}`, right - 240, summaryTop + 32, {width: 240, align: "right"});

  const signatureTop = doc.page.height - 78;
  const sigWidth = 238;
  const sigLabels = ["AGENT", "SUPERVISOR", "ACCOUNTS"];
  for (let i = 0; i < sigLabels.length; i++) {
    const sigLeft = left + i * 285;
    doc.moveTo(sigLeft, signatureTop).lineTo(sigLeft + sigWidth, signatureTop).stroke();
    doc.font("Helvetica").fontSize(14)
        .text(sigLabels[i], sigLeft, signatureTop + 12, {width: sigWidth, align: "center"});
  }

  if (pageCount > 1) {
    doc.font("Helvetica").fontSize(10)
        .text(`Page ${pageIndex + 1} of ${pageCount}`, right - 80, doc.page.height - 26, {
          width: 80,
          align: "right",
        });
  }
}

async function generateCompanyInvoicePdf({
  companyName,
  agentName,
  invoiceDate,
  closingRate,
  rows,
  summary,
}) {
  const fileName = `invoice_${Date.now()}.pdf`;
  const tmpPath = path.join(os.tmpdir(), fileName);
  const rowsPerPage = 11;
  const pageCount = Math.max(1, Math.ceil(rows.length / rowsPerPage));

  await new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: "LETTER",
      margin: 0,
    });
    const stream = fs.createWriteStream(tmpPath);
    doc.pipe(stream);

    for (let pageIndex = 0; pageIndex < pageCount; pageIndex++) {
      if (pageIndex > 0) doc.addPage({size: "LETTER", margin: 0});
      const pageRows = rows.slice(pageIndex * rowsPerPage, (pageIndex + 1) * rowsPerPage);
      drawInvoiceTemplatePage({
        doc,
        invoiceDate,
        closingRate,
        companyName,
        agentName,
        rows: pageRows,
        pageIndex,
        pageCount,
        summary,
      });
    }

    doc.end();
    stream.on("finish", resolve);
    stream.on("error", reject);
  });

  return {tmpPath, fileName};
}

async function uploadGeneratedInvoicePdf({
  companyName,
  yearWeek,
  pdf,
}) {
  const storagePath = buildInvoiceStoragePath(companyName, yearWeek);
  const fileBuffer = await fs.promises.readFile(pdf.tmpPath);
  await storeBufferInR2({
    storagePath,
    body: fileBuffer,
    contentType: "application/pdf",
  });
  await fs.promises.unlink(pdf.tmpPath).catch(() => null);
  const downloadUrl = await createR2DownloadUrl(storagePath, {
    inline: true,
    fileName: path.basename(storagePath),
  });
  return {
    storagePath,
    downloadUrl,
  };
}

function loadMatchesRange(load, companyId, startDate, endDate, selectedDriverIds) {
  if (String(load.companyId || "") !== companyId) return false;
  const loadDate = parseDateValue(load.date);
  if (!loadDate || loadDate < startDate || loadDate > endDate) return false;
  if (selectedDriverIds.length > 0 && !selectedDriverIds.includes(String(load.driverId || ""))) {
    return false;
  }
  return true;
}

async function createCompanyInvoiceInternal({
  requesterName,
  actorUid,
  companyId,
  startDateRaw,
  endDateRaw,
  agentName,
  driverIds,
  explicitLoadIds,
}) {
  const startDate = parseDateValue(startDateRaw);
  const endDate = parseDateValue(endDateRaw);
  if (!startDate || !endDate) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid date range.");
  }
  if (startDate > endDate) {
    throw new functions.https.HttpsError("invalid-argument", "Start date must be on or before end date.");
  }

  const [loadsSnap, companiesSnap, invoicesSnap] = await Promise.all([
    db.ref("loads").get(),
    db.ref("companies").get(),
    db.ref("invoices").get(),
  ]);

  const companies = companiesSnap.val() || {};
  const company = companies[companyId];
  if (!company) {
    throw new functions.https.HttpsError("not-found", "Company not found.");
  }

  const allLoads = Object.entries(loadsSnap.val() || {}).map(([id, value]) => ({
    id,
    ...value,
  }));

  let matchingLoads = allLoads.filter((load) => loadMatchesRange(
      load,
      companyId,
      startDate,
      endDate,
      driverIds,
  ));

  if (explicitLoadIds.length > 0) {
    matchingLoads = matchingLoads.filter((load) => explicitLoadIds.includes(load.id));
  }

  if (matchingLoads.length === 0) {
    throw new functions.https.HttpsError("failed-precondition", "No matching loads found for the selected company and date range.");
  }

  const invalidLoad = matchingLoads.find((load) => !load.loadNumber || !load.dispatchFeeAmount);
  if (invalidLoad) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        `Missing load data required for invoicing on ${invalidLoad.id}.`,
    );
  }

  const normalizedDriverIds = driverIds.length > 0 ?
    driverIds :
    [...new Set(matchingLoads.map((load) => String(load.driverId || "")))].filter(Boolean);
  const dedupeKey = buildInvoiceDedupeKey({
    companyId,
    startDate: formatDateValue(startDate),
    endDate: formatDateValue(endDate),
    driverIds: normalizedDriverIds,
  });

  const invoices = invoicesSnap.val() || {};
  const existing = Object.entries(invoices).find(([, invoice]) => invoice.dedupeKey === dedupeKey);
  if (existing) {
    const [invoiceId, invoice] = existing;
    const storagePath = String(invoice.storagePath || "");
    const downloadUrl = storagePath ?
      await createR2DownloadUrl(storagePath, {
        inline: true,
        fileName: path.basename(storagePath),
      }) :
      String(invoice.invoiceFileUrl || "");
    return {
      invoiceId,
      invoiceNumber: invoice.invoiceNumber,
      invoiceFileUrl: downloadUrl,
      storagePath,
      existing: true,
    };
  }

  const totals = {
    totalLoads: matchingLoads.length,
    totalGross: matchingLoads.reduce((sum, load) => sum + Number(load.loadRate || 0), 0),
    totalDispatchFee: matchingLoads.reduce((sum, load) => sum + Number(load.dispatchFeeAmount || 0), 0),
  };
  const feePercentage = Number(company.feePercentage || matchingLoads[0].feePercentage || 0);
  const yearWeek = matchingLoads[0].yearWeek || isoWeekParts(startDate).yearWeek;
  const invoiceId = db.ref("invoices").push().key;
  const invoiceNumber = buildInvoiceNumber(invoices);
  const invoiceDate = formatDateValue(new Date());
  const dueDate = formatDateValue(new Date(Date.now() + 15 * 24 * 60 * 60 * 1000));

  const rows = matchingLoads
      .sort((a, b) => String(a.loadNumber).localeCompare(String(b.loadNumber)))
      .map((load) => ({
        loadNumber: String(load.loadNumber || "N/A"),
        details: `${String(load.pickupLocation || "Unknown")} → ${String(load.deliveryLocation || "Unknown")}`,
        duration: `${formatDateValue(load.date)} → ${formatDateValue(load.deliveryDateTime || load.date)}`,
        amount: `$${Number(load.dispatchFeeAmount || 0).toFixed(2)}`,
        status: selectInvoiceStatus(load),
      }));

  const pdf = await generateCompanyInvoicePdf({
    companyName: company.name || "Carrier",
    agentName,
    invoiceDate,
    closingRate: `${feePercentage.toFixed(2)}%`,
    rows,
    summary: totals,
  });
  const upload = await uploadGeneratedInvoicePdf({
    companyName: company.name || companyId,
    yearWeek,
    pdf,
  });

  const invoiceRecord = {
    invoiceNumber,
    loadId: matchingLoads[0].id,
    loadIds: matchingLoads.map((load) => load.id),
    companyId,
    companyName: company.name || "",
    dispatcherId: String(matchingLoads[0].dispatcherId || ""),
    driverId: String(matchingLoads[0].driverId || ""),
    driversIncluded: normalizedDriverIds,
    year: Number(matchingLoads[0].year || 0),
    week: Number(matchingLoads[0].week || 0),
    yearWeek,
    invoiceDate,
    startDate: formatDateValue(startDate),
    endDate: formatDateValue(endDate),
    totalLoads: totals.totalLoads,
    totalGross: totals.totalGross,
    feePercentage,
    closingRate: feePercentage,
    dispatchFeeAmount: totals.totalDispatchFee,
    invoiceAmount: totals.totalDispatchFee,
    dueDate,
    invoiceFileUrl: "",
    storagePath: upload.storagePath,
    agentName,
    dedupeKey,
    status: "Generated",
    invoiceStatus: "Generated",
    paymentStatus: "Unpaid",
    sentDate: "",
    paidDate: "",
    notes: "",
    createdAt: new Date().toISOString(),
    dateRange: {
      startDate: formatDateValue(startDate),
      endDate: formatDateValue(endDate),
    },
    totalAmount: totals.totalDispatchFee,
  };

  await Promise.all([
    db.ref(`invoices/${invoiceId}`).set(invoiceRecord),
    ...matchingLoads.map((load) => db.ref(`loads/${load.id}`).update({
      invoiceStatus: "Generated",
      financialStatus: "Invoice Generated",
      paymentStatus: "Unpaid",
      latestInvoiceId: invoiceId,
      updatedDate: new Date().toISOString(),
    })),
    ...matchingLoads.map((load) => addActivityLog({
      loadId: load.id,
      type: "invoice_generated",
      message: `Weekly invoice ${invoiceNumber} generated.`,
      actorId: actorUid,
      actorName: requesterName || "Accounting",
    })),
  ]);

  return {
    invoiceId,
    invoiceNumber,
    invoiceFileUrl: upload.downloadUrl,
    storagePath: upload.storagePath,
    totalLoads: totals.totalLoads,
    totalAmount: totals.totalDispatchFee,
    totalGross: totals.totalGross,
    existing: false,
  };
}

exports.generateR2UploadUrl = functions.https.onCall(async (data, context) => {
  try {
    logger.info("generateR2UploadUrl entry", {
      authenticated: Boolean(context.auth),
    });
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication is required.");
    }
    const requester = (await db.ref(`users/${context.auth.uid}`).get()).val();
    if (!requester?.role) {
      throw new functions.https.HttpsError("permission-denied", "User role is required.");
    }

    const payload = validateUploadPayload(data);
    const config = getR2Config();
    const storagePath = buildR2ObjectPath(payload);
    logger.info("generateR2UploadUrl validated", {
      accountId: config.accountId,
      endpoint: config.endpoint,
      bucket: config.bucketName,
      storagePath,
      mimeType: payload.mimeType,
      documentType: payload.documentType,
      role: requester.role,
    });

    const uploadUrl = await createR2UploadUrl(storagePath, {
      contentType: payload.mimeType,
    });
    const downloadUrl = await createR2DownloadUrl(storagePath, {
      inline: true,
      fileName: payload.fileName,
    });
    logger.info("generateR2UploadUrl success", {
      storagePath,
      mimeType: payload.mimeType,
    });
    return {
      uploadUrl,
      downloadUrl,
      storagePath,
      fileName: payload.fileName,
      mimeType: payload.mimeType,
      headers: {
        "Content-Type": payload.mimeType,
      },
    };
  } catch (error) {
    throw toHttpsStorageError(error, "Unable to connect to Cloudflare R2 for upload URL generation.");
  }
});

exports.generateR2DownloadUrl = functions.https.onCall(async (data, context) => {
  try {
    logger.info("generateR2DownloadUrl entry", {
      authenticated: Boolean(context.auth),
    });
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication is required.");
    }
    const requester = (await db.ref(`users/${context.auth.uid}`).get()).val();
    if (!requester?.role) {
      throw new functions.https.HttpsError("permission-denied", "User role is required.");
    }

    const storagePath = String(data.storagePath || "").trim();
    const inline = data.inline !== false;
    const fileName = String(data.fileName || path.basename(storagePath) || "document");
    if (!storagePath) {
      throw new functions.https.HttpsError("invalid-argument", "storagePath is required.");
    }
    const config = getR2Config();
    logger.info("generateR2DownloadUrl validated", {
      accountId: config.accountId,
      endpoint: config.endpoint,
      bucket: config.bucketName,
      storagePath,
      inline,
    });

    const downloadUrl = await createR2DownloadUrl(storagePath, {
      inline,
      fileName,
    });
    return {
      downloadUrl,
      storagePath,
    };
  } catch (error) {
    throw toHttpsStorageError(error, "Unable to connect to Cloudflare R2 for download URL generation.");
  }
});

exports.deleteR2Object = functions.https.onCall(async (data, context) => {
  try {
    logger.info("deleteR2Object entry", {
      authenticated: Boolean(context.auth),
    });
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication is required.");
    }
    const requester = (await db.ref(`users/${context.auth.uid}`).get()).val();
    const role = requester?.role;
    if (!["admin", "accountant", "paperwork"].includes(role)) {
      throw new functions.https.HttpsError("permission-denied", "You cannot delete stored documents.");
    }

    const storagePath = String(data.storagePath || "").trim();
    if (!storagePath) {
      throw new functions.https.HttpsError("invalid-argument", "storagePath is required.");
    }

    const client = createR2Client();
    const config = getR2Config();
    logger.info("deleteR2Object validated", {
      accountId: config.accountId,
      endpoint: config.endpoint,
      bucket: config.bucketName,
      storagePath,
    });
    await client.send(new DeleteObjectCommand({
      Bucket: config.bucketName,
      Key: storagePath,
    }));

    return {success: true, storagePath};
  } catch (error) {
    throw toHttpsStorageError(error, "Unable to delete the Cloudflare R2 object.");
  }
});

// TEMPORARY DEBUG ONLY: remove after verifying R2 config and credentials.
exports.r2DebugSelfTest = functions.https.onCall(async (data, context) => {
  try {
    logger.info("r2DebugSelfTest entry", {
      authenticated: Boolean(context.auth),
    });
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication is required.");
    }
    const requester = (await db.ref(`users/${context.auth.uid}`).get()).val();
    if (requester?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Only admin can run the R2 debug self-test.");
    }
    if (String((functions.config().r2 || {}).debug_enabled || "false") !== "true") {
      throw new functions.https.HttpsError(
          "failed-precondition",
          "Temporary R2 debug self-test is disabled. Enable r2.debug_enabled=true only while diagnosing upload issues.",
      );
    }
    const config = getR2Config();
    const storagePath = "test/hello.txt";
    const body = Buffer.from("hello from dispatch r2 debug");
    logger.info("r2DebugSelfTest validated", {
      accountId: config.accountId,
      endpoint: config.endpoint,
      bucket: config.bucketName,
      storagePath,
      mimeType: "text/plain",
    });
    await storeBufferInR2({
      storagePath,
      body,
      contentType: "text/plain",
    });
    logger.info("r2DebugSelfTest success", {storagePath});
    return {
      success: true,
      storagePath,
      bucket: config.bucketName,
      endpoint: config.endpoint,
    };
  } catch (error) {
    throw toHttpsStorageError(error, "R2 debug self-test failed.");
  }
});

exports.generateInvoicePdfAndStore = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication is required.");
  }

  const requester = (await db.ref(`users/${context.auth.uid}`).get()).val();
  const role = requester?.role;
  if (role !== "admin" && role !== "accountant") {
    throw new functions.https.HttpsError("permission-denied", "Only accountant or admin can generate invoices.");
  }

  const companyId = String(data.companyId || "");
  const startDateRaw = String(data.startDate || "");
  const endDateRaw = String(data.endDate || "");
  const agentName = String(data.agentName || requester?.name || "Agent");
  const explicitLoadIds = Array.isArray(data.explicitLoadIds) ?
    data.explicitLoadIds.map((item) => String(item)) : [];
  const driverIds = Array.isArray(data.driverIds) ?
    data.driverIds.map((item) => String(item)).filter((item) => item.length > 0) : [];

  if (!companyId || !startDateRaw || !endDateRaw) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "companyId, startDate, and endDate are required.",
    );
  }

  return createCompanyInvoiceInternal({
    requesterName: requester?.name || "Accounting",
    actorUid: context.auth.uid,
    companyId,
    startDateRaw,
    endDateRaw,
    agentName,
    driverIds,
    explicitLoadIds,
  });
});

exports.syncUserClaims = functions.database.ref("/users/{uid}").onWrite(async (change, context) => {
  const uid = context.params.uid;
  const user = change.after.val();

  if (!user) {
    await admin.auth().setCustomUserClaims(uid, null);
    return null;
  }

  const claims = {
    role: user.role || "dispatcher",
    dispatcherId: user.dispatcherId || "",
    active: user.active !== false,
  };

  await admin.auth().setCustomUserClaims(uid, claims);
  logger.info("Synced custom claims", {uid, claims});
  return null;
});

exports.generateInvoice = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication is required.");
  }

  const requester = (await db.ref(`users/${context.auth.uid}`).get()).val();
  const role = requester?.role;
  if (role !== "admin" && role !== "accountant") {
    throw new functions.https.HttpsError("permission-denied", "Only accountant or admin can generate invoices.");
  }

  const loadId = data.loadId;
  if (!loadId) {
    throw new functions.https.HttpsError("invalid-argument", "loadId is required.");
  }

  const loadSnap = await db.ref(`loads/${loadId}`).get();
  const load = loadSnap.val();
  if (!load) {
    throw new functions.https.HttpsError("not-found", "Load not found.");
  }

  if (load.operationalStatus !== "Delivered") {
    throw new functions.https.HttpsError("failed-precondition", "Load must be Delivered before invoicing.");
  }

  if (load.paperworkStatus !== "Complete") {
    throw new functions.https.HttpsError("failed-precondition", "Paperwork must be complete before invoicing.");
  }

  return createCompanyInvoiceInternal({
    requesterName: requester?.name || "Accounting",
    actorUid: context.auth.uid,
    companyId: String(load.companyId || ""),
    startDateRaw: String(load.date || ""),
    endDateRaw: String(load.date || ""),
    agentName: requester?.name || load.dispatcherName || "Agent",
    driverIds: [String(load.driverId || "")],
    explicitLoadIds: [loadId],
  });
});

exports.generateCompanyInvoice = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication is required.");
  }

  const requester = (await db.ref(`users/${context.auth.uid}`).get()).val();
  const role = requester?.role;
  if (role !== "admin" && role !== "accountant") {
    throw new functions.https.HttpsError("permission-denied", "Only accountant or admin can generate invoices.");
  }

  const companyId = String(data.companyId || "");
  const startDateRaw = String(data.startDate || "");
  const endDateRaw = String(data.endDate || "");
  const agentName = String(data.agentName || requester?.name || "Agent");
  const explicitLoadIds = Array.isArray(data.explicitLoadIds) ?
    data.explicitLoadIds.map((item) => String(item)) : [];
  const driverIds = Array.isArray(data.driverIds) ?
    data.driverIds.map((item) => String(item)).filter((item) => item.length > 0) : [];

  if (!companyId || !startDateRaw || !endDateRaw) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "companyId, startDate, and endDate are required.",
    );
  }

  return createCompanyInvoiceInternal({
    requesterName: requester?.name || "Accounting",
    actorUid: context.auth.uid,
    companyId,
    startDateRaw,
    endDateRaw,
    agentName,
    driverIds,
    explicitLoadIds,
  });
});

exports.flagPaperworkAlerts = functions.database.ref("/loads/{loadId}").onWrite(async (change, context) => {
  const loadId = context.params.loadId;
  const load = change.after.val();
  if (!load) return null;

  if (load.operationalStatus === "Delivered" && load.paperworkStatus !== "Complete") {
    await db.ref(`paperworkAlerts/${loadId}`).set({
      loadId,
      loadNumber: load.loadNumber || "",
      dispatcherName: load.dispatcherName || "",
      companyName: load.companyName || "",
      missingDocumentsCount: Number(load.missingDocumentsCount || 0),
      createdAt: new Date().toISOString(),
      status: "Open",
    });
  } else {
    await db.ref(`paperworkAlerts/${loadId}`).remove();
  }

  return rebuildWeeklySummariesForLoad(load);
});

exports.podDelaySweep = functions.pubsub
    .schedule("every 2 hours")
    .timeZone("America/Los_Angeles")
    .onRun(async () => {
      const loadsSnap = await db.ref("loads").get();
      const usersSnap = await db.ref("users").get();
      const loads = Object.entries(loadsSnap.val() || {}).map(([id, value]) => ({
        id,
        ...value,
      }));
      const users = usersSnap.val() || {};
      const now = Date.now();

      for (const load of loads) {
        if (!load.deliveryDateTime || load.podUploaded === true) continue;

        const deliveryMs = Date.parse(load.deliveryDateTime);
        if (!deliveryMs || now - deliveryMs <= 24 * 60 * 60 * 1000) continue;
        if (load.podDelayFlag === true) continue;

        await db.ref(`loads/${load.id}`).update({
          podDelayFlag: true,
          updatedDate: new Date().toISOString(),
        });

        const dispatcherUserEntry = Object.entries(users).find(([, user]) => (
          user.dispatcherId === load.dispatcherId
        ));

        if (dispatcherUserEntry) {
          const [dispatcherUid, dispatcherUser] = dispatcherUserEntry;
          await createNotification({
            userId: dispatcherUid,
            title: "POD overdue",
            message: `Load ${load.loadNumber || load.id} is more than 24 hours past delivery without a POD.`,
            loadId: load.id,
            type: "pod_delay",
          });
          await addActivityLog({
            loadId: load.id,
            type: "pod_delay_flagged",
            message: `POD delay flagged for ${load.loadNumber || load.id}.`,
            actorId: "",
            actorName: dispatcherUser.name || "System",
          });
        }
      }

      logger.info("Completed POD delay sweep", {checked: loads.length});
      return null;
    });

exports.dailyAdminSummary = functions.pubsub
    .schedule("0 18 * * *")
    .timeZone("America/Los_Angeles")
    .onRun(async () => {
      const [loadsSnap, invoicesSnap] = await Promise.all([
        db.ref("loads").get(),
        db.ref("invoices").get(),
      ]);

      const loads = Object.values(loadsSnap.val() || {});
      const invoices = Object.values(invoicesSnap.val() || {});

      const summary = {
        generatedAt: new Date().toISOString(),
        totalLoadsCreated: loads.length,
        totalDelivered: loads.filter((load) => load.operationalStatus === "Delivered").length,
        pendingPaperwork: loads.filter((load) => load.paperworkStatus !== "Complete").length,
        invoicesGenerated: invoices.length,
        unpaidTotals: invoices
            .filter((invoice) => invoice.paymentStatus !== "Paid")
            .reduce((sum, invoice) => sum + Number(invoice.invoiceAmount || 0), 0),
      };

      await db.ref("adminSummaries").push(summary);
      logger.info("Daily admin summary written", summary);
      return null;
    });
