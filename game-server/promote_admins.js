const admin = require('firebase-admin');
const serviceAccount = require('./firebase-service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

const emails = [
    'almalexyz@gmail.com',
    'ormix16@gmail.com',
    'raisvladimir@gmail.com'
];

async function promote() {
    console.log('--- Promoting Admins ---');
    for (const email of emails) {
        try {
            const userRecord = await auth.getUserByEmail(email);
            const uid = userRecord.uid;

            await db.collection('users').doc(uid).set({
                isAdmin: true
            }, { merge: true });

            console.log(`✅ Success: ${email} (UID: ${uid}) is now an admin.`);
        } catch (error) {
            console.log(`❌ Error promoting ${email}: ${error.message}`);
        }
    }
    console.log('--- Finished ---');
    process.exit();
}

promote();
