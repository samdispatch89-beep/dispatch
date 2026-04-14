const functions = require("firebase-functions");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const PDFDocument = require("pdfkit");
const fs = require("fs");
const os = require("os");
const path = require("path");

admin.initializeApp();

const db = admin.database();
const bucket = admin.storage().bucket();

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

async function generateInvoicePdf(load, invoiceNumber, dueDate) {
  const tmpPath = path.join(os.tmpdir(), `${invoiceNumber}.pdf`);

  await new Promise((resolve, reject) => {
    const doc = new PDFDocument({margin: 50});
    const stream = fs.createWriteStream(tmpPath);
    doc.pipe(stream);

    doc.fontSize(20).text("Dispatch Invoice");
    doc.moveDown();
    doc.fontSize(12).text(`Invoice Number: ${invoiceNumber}`);
    doc.text(`Invoice Date: ${new Date().toISOString().slice(0, 10)}`);
    doc.text(`Due Date: ${dueDate}`);
    doc.moveDown();
    doc.text(`Company: ${load.companyName}`);
    doc.text(`Load Number: ${load.loadNumber}`);
    doc.text(`Route: ${load.routeSummary}`);
    doc.text(`Dispatcher: ${load.dispatcherName}`);
    doc.text(`Brokerage: ${load.brokerageName}`);
    doc.moveDown();
    doc.text(`Load Rate: $${Number(load.loadRate || 0).toFixed(2)}`);
    doc.text(`Dispatch Fee %: ${Number(load.feePercentage || 0).toFixed(2)}%`);
    doc.text(`Dispatch Fee Amount: $${Number(load.dispatchFeeAmount || 0).toFixed(2)}`);
    doc.text(`Invoice Amount: $${Number(load.dispatcherRevenue || 0).toFixed(2)}`);
    doc.moveDown();
    doc.text(`Notes: ${load.notes || "N/A"}`);
    doc.end();

    stream.on("finish", resolve);
    stream.on("error", reject);
  });

  return tmpPath;
}

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

  if (load.status !== "Delivered") {
    throw new functions.https.HttpsError("failed-precondition", "Load must be Delivered before invoicing.");
  }

  if (load.paperworkStatus !== "Complete") {
    throw new functions.https.HttpsError("failed-precondition", "Paperwork must be complete before invoicing.");
  }

  const invoicesSnap = await db.ref("invoices").get();
  const invoices = invoicesSnap.val() || {};
  const existing = Object.entries(invoices).find(([, invoice]) => invoice.loadId === loadId);
  if (existing) {
    const [existingId, invoice] = existing;
    return {
      invoiceId: existingId,
      invoiceNumber: invoice.invoiceNumber,
      existing: true,
    };
  }

  const invoiceId = db.ref("invoices").push().key;
  const invoiceNumber = buildInvoiceNumber(invoices);
  const now = new Date();
  const invoiceDate = now.toISOString().slice(0, 10);
  const dueDate = new Date(now.getTime() + 15 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const filePath = await generateInvoicePdf(load, invoiceNumber, dueDate);
  const storagePath = `invoices/${now.getUTCFullYear()}/${invoiceNumber}.pdf`;

  await bucket.upload(filePath, {
    destination: storagePath,
    metadata: {
      contentType: "application/pdf",
    },
  });

  const [downloadUrl] = await bucket.file(storagePath).getSignedUrl({
    action: "read",
    expires: "2100-01-01",
  });

  const invoice = {
    invoiceNumber,
    loadId,
    companyName: load.companyName || "",
    invoiceDate,
    feePercentage: Number(load.feePercentage || 0),
    dispatchFeeAmount: Number(load.dispatchFeeAmount || 0),
    invoiceAmount: Number(load.dispatcherRevenue || 0),
    dueDate,
    invoiceFileUrl: downloadUrl,
    storagePath,
    invoiceStatus: "Generated",
    paymentStatus: "Unpaid",
    sentDate: "",
    paidDate: "",
    notes: "",
  };

  await db.ref(`invoices/${invoiceId}`).set(invoice);
  await db.ref(`loads/${loadId}`).update({
    invoiceStatus: "Generated",
    paymentStatus: "Unpaid",
    updatedDate: new Date().toISOString(),
  });

  return {
    invoiceId,
    invoiceNumber,
    invoiceFileUrl: downloadUrl,
    existing: false,
  };
});

exports.flagPaperworkAlerts = functions.database.ref("/loads/{loadId}").onWrite(async (change, context) => {
  const loadId = context.params.loadId;
  const load = change.after.val();
  if (!load) {
    return null;
  }

  if (load.status === "Delivered" && load.paperworkStatus !== "Complete") {
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
        totalDelivered: loads.filter((load) => load.status === "Delivered").length,
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
