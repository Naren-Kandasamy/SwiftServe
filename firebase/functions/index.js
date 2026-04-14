const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Admin SDK to allow cross-path DB writes
admin.initializeApp();

const classifyAlertLogic = require('./src/classifyAlert');

exports.classifyAlert = functions.database.ref('/venues/{venueId}/alerts/{alertId}')
    .onCreate(classifyAlertLogic.processAlert);

exports.generateInstructions = functions.database.ref('/venues/{venueId}/alerts/{alertId}')
    .onUpdate((change, context) => {
      // Placeholder for safety instructions generation
      return null;
    });

exports.analyseImage = functions.https.onCall((data, context) => {
      // Placeholder for Cloud Vision analysis
      return { visualContext: "none", suggestedType: null };
    });

exports.detectEscalation = functions.pubsub.schedule('every 1 minutes').onRun((context) => {
      // Placeholder for clustering detection
      return null;
    });

exports.generateResponderBrief = functions.https.onCall((data, context) => {
      // Placeholder for responder brief generation
      return { responderBriefUrl: "https://example.com/brief" };
    });
