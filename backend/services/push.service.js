const admin = require("firebase-admin");

const messageBuilders = {
    new_event: (p) => ({
        title: "New Event",
        body: p.eventTitle ? `New event: ${p.eventTitle}` : "A new event has been created",
    }),
    new_issue: (p) => ({
        title: "New Issue Reported",
        body: `HIGH severity issue on ${p.wallName || "a wall"}`,
    }),
    group_invite: (p) => ({
        title: "Group Invitation",
        body: `${p.invitedByName || "Someone"} invited you to "${p.groupName || "a group"}"`,
    }),
    badge_awarded: (p) => ({
        title: "Badge Earned!",
        body: p.badgeName ? `You earned: ${p.badgeName}` : "You earned a new badge!",
    }),
    new_follower: (p) => ({
        title: "New Follower",
        body: `${p.followerName || "Someone"} started following you`,
    }),
    issue_status_changed: (p) => ({
        title: "Issue Updated",
        body: `Your issue on ${p.wallName || "a wall"} is now ${p.newStatus || "updated"}`,
    }),
    new_message: (p) => ({
        title: p.senderName || "New message",
        body: p.messagePreview || "You have a new message",
    }),
    support_ticket_replied: (p) => ({
        title: "Support Reply",
        body: p.ticketSubject ? `Reply to: ${p.ticketSubject}` : "Your support ticket has been updated",
    }),
};

exports.sendToTokens = async (tokens, type, payload) => {
    if (!tokens || tokens.length === 0) return;

    const app = admin.apps[0];
    if (!app) {
        console.warn("push.service: Firebase Admin not initialized, skipping push");
        return;
    }

    const builder = messageBuilders[type];
    if (!builder) return;

    const { title, body } = builder(payload || {});

    // FCM data values must all be strings
    const data = Object.fromEntries(
        Object.entries({ type, ...payload }).map(([k, v]) => [k, String(v ?? "")])
    );

    try {
        const result = await app.messaging().sendEachForMulticast({ notification: { title, body }, data, tokens });
        if (result.failureCount > 0) {
            result.responses.forEach((r, i) => {
                if (!r.success) {
                    console.warn(`push.service: token[${i}] failed:`, r.error?.message);
                }
            });
        }
    } catch (err) {
        console.error("push.service: sendEachForMulticast error:", err.message);
    }
};
