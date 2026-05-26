const Badge = require("../models/Badge");
const ClimbingSession = require("../models/ClimbingSession");
const { Climber } = require("../models/User");
const climberService = require("./climber.service");

const createBadge = async (badgeData) => {
    const badge = new Badge(badgeData);
    return await badge.save();
};

const getBadges = async (filter = {}) => {
    return await Badge.find(filter);
};

const getBadgeById = async (badgeId) => {
    return await Badge.findById(badgeId);
};

const updateBadge = async (badgeId, updateData) => {
    return await Badge.findByIdAndUpdate(badgeId, updateData, {
        new: true,
        runValidators: true,
    });
};

const deleteBadge = async (badgeId) => {
    return await Badge.findByIdAndDelete(badgeId);
};

const evaluateSystemBadges = async (userId) => {
    const climber = await Climber.findById(userId).populate("wallet.badges.badge");
    if (!climber) return;

    const sessions = await ClimbingSession.find({ climber_id: userId }).sort({ date: 1 });
    const sessionCount = sessions.length;

    const badges = await Badge.find({ type: "system" });
    const badgeMap = {};
    badges.forEach((b) => { badgeMap[b.name] = b; });

    const acquiredMap = {};
    if (climber.wallet && climber.wallet.badges) {
        climber.wallet.badges.forEach((b) => {
            if (b.badge && b.badge.name) {
                acquiredMap[b.badge.name] = (acquiredMap[b.badge.name] || 0) + 1;
            }
        });
    }

    const awardBadge = async (badgeName) => {
        const badge = badgeMap[badgeName];
        if (!badge) return;
        
        if (!badge.reEarnable && acquiredMap[badgeName]) return;
        
        try {
            await climberService.acquireBadge(userId, badge._id);
            acquiredMap[badgeName] = (acquiredMap[badgeName] || 0) + 1;
            console.log(`Badge '${badgeName}' awarded to user ${userId}`);
        } catch (error) {
            console.error(`Error awarding badge ${badgeName}:`, error.message);
        }
    };

    // Rule 1: First Ascent
    if (sessionCount >= 1) {
        await awardBadge("First Ascent");
    }

    // Rule 2: Century Club
    if (sessionCount >= 100) {
        await awardBadge("Century Club");
    }

    // Rule 3: Weekend Warrior
    if (sessions.length >= 2) {
        const lastSession = sessions[sessions.length - 1];
        const lastDate = new Date(lastSession.date);
        const day = lastDate.getDay(); 
        
        if (day === 0 || day === 6) {
            const targetDay = day === 0 ? 6 : 0; // The other weekend day
            const otherDaySession = sessions.find((s) => {
                const sDate = new Date(s.date);
                if (sDate.getDay() !== targetDay) return false;
                const diffDays = Math.ceil(Math.abs(lastDate - sDate) / (1000 * 60 * 60 * 24));
                return diffDays <= 2; // within the same weekend
            });

            if (otherDaySession) {
                await awardBadge("Weekend Warrior");
            }
        }
    }
};

module.exports = {
    createBadge,
    getBadges,
    getBadgeById,
    updateBadge,
    deleteBadge,
    evaluateSystemBadges,
};
