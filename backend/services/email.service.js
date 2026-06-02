const nodemailer = require("nodemailer");

let transporter;

if (process.env.SMTP_HOST && process.env.SMTP_PORT) {
    transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT, 10),
        secure: process.env.SMTP_PORT === "465",
        auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS,
        },
    });
}

const sendEmail = async (to, subject, text) => {
    if (transporter) {
        try {
            await transporter.sendMail({
                from: '"Hookd Admin" <admin@hookd.com>',
                to,
                subject,
                text,
            });
            console.log(`Email sent to ${to}: ${subject}`);
        } catch (error) {
            console.error("Error sending email: ", error);
        }
    } else {
        // Fallback for local development if SMTP not configured
        console.log(`[MOCK EMAIL] To: ${to} | Subject: ${subject}`);
        console.log(`[MOCK EMAIL BODY]\n${text}\n-------------------`);
    }
};

exports.sendAccountApprovedEmail = async (user) => {
    const subject = "Your Hookd Account Request has been Approved!";
    const text = `Hello,\n\nYour account request has been reviewed and approved by an admin. You can now log in and access your account features.\n\nBest,\nHookd Team`;
    await sendEmail(user.email, subject, text);
};

exports.sendAccountRejectedEmail = async (user) => {
    const subject = "Update regarding your Hookd Account Request";
    const text = `Hello,\n\nUnfortunately, your account request has been rejected by our admin team. If you believe this is a mistake, please reach out to support.\n\nBest,\nHookd Team`;
    await sendEmail(user.email, subject, text);
};

exports.sendContentRemovedEmail = async (user, reason) => {
    const subject = "Your review has been removed";
    const text = `Hello,\n\nOne of your reviews has been removed by a moderator.\n\nReason: ${reason || "Violation of community guidelines"}\n\nIf you believe this was a mistake, please contact support.\n\nBest,\nHookd Team`;
    await sendEmail(user.email, subject, text);
};
