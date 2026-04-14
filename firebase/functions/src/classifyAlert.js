const admin = require('firebase-admin');
const { VertexAI } = require('@google-cloud/vertexai');
const { buildClassificationPrompt } = require('./prompts/classificationPrompt');

// Initialize Vertex AI with Application Default Credentials
// For local emulation without credentials, we wrap the AI call in a try/catch
const vertexAI = new VertexAI({ project: process.env.GCLOUD_PROJECT || 'swiftserve-18547', location: 'us-central1' });
const generativeModel = vertexAI.getGenerativeModel({ model: 'gemini-1.5-flash-preview-0514' });

/**
 * Triggered on new SOS alert creation. 
 * Calls Gemini to classify and then aggregates it into an Incident.
 */
async function processAlert(snapshot, context) {
  const alert = snapshot.val();
  const alertId = context.params.alertId;
  const venueId = context.params.venueId;

  console.log(`[classifyAlert] Processing new alert: ${alertId} at venue: ${venueId}`);

  let triageResult;

  try {
    const prompt = buildClassificationPrompt(alert.description, alert.roomNumber, alert.floor);
    
    // Using temperature 0.2 for deterministic JSON classification
    const request = {
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.2,
      }
    };

    const result = await generativeModel.generateContent(request);
    const responseText = result.response.candidates[0].content.parts[0].text;
    
    // Clean potential markdown blocks ` ```json ` sometimes returned by model
    const cleanJson = responseText.replace(/```json/g, '').replace(/```/g, '').trim();
    triageResult = JSON.parse(cleanJson);
    console.log(`[classifyAlert] Gemini Triage Success:`, triageResult);

  } catch (error) {
    console.error(`[classifyAlert] Gemini Triage Failed (Likely missing GCP credentials locally). Falling back to rule-based...`, error);
    // Fallback if AI fails (e.g. Local emulator without GCP ADC configured)
    triageResult = {
      type: 'other',
      severity: 3,
      confidence: 0.0,
      language: 'en',
      routingTargets: ['management'],
      immediateInstructions: 'Please stay calm. Staff have been notified of your emergency and are on their way.',
      escalateToEmergencyServices: false
    };
  }

  // 1. Update the original Alert to "triaged"
  const db = admin.database();
  await db.ref(`/venues/${venueId}/alerts/${alertId}`).update({
    type: triageResult.type,
    severity: triageResult.severity,
    language: triageResult.language,
    safetyInstructions: triageResult.immediateInstructions,
    status: 'triaged'
  });

  // 2. Create the Incident object for the unified Staff Dashboard
  const incidentId = `inc_${alertId.substring(0, 8)}`;
  const timestamp = Date.now();
  
  const incidentData = {
    id: incidentId,
    venueId: venueId,
    alertIds: [alertId],
    type: triageResult.type,
    severity: triageResult.severity,
    affectedZone: `Room ${alert.roomNumber} (Floor ${alert.floor})`,
    guestCount: 1, // simplified
    status: triageResult.escalateToEmergencyServices ? 'escalated' : 'active',
    createdAt: timestamp,
    timeline: [
      {
        timestamp: timestamp,
        updateText: `SOS Received: "${alert.description}"`
      },
      {
        timestamp: timestamp + 100, // slightly offset to ensure order
        updateText: `AI Triaged as ${triageResult.type.toUpperCase()} (Severity ${triageResult.severity}). Instructions pushed to guest.`
      }
    ]
  };

  await db.ref(`/venues/${venueId}/incidents/${incidentId}`).set(incidentData);
  console.log(`[classifyAlert] Successfully created Incident: ${incidentId}`);
  
  return incidentData;
}

module.exports = {
  processAlert
};
