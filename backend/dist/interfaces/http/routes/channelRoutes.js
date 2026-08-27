"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const channelController_1 = require("../controllers/channelController");
const authMiddleware_1 = require("../middleware/authMiddleware");
const router = (0, express_1.Router)();
router.get("/", authMiddleware_1.authenticate, channelController_1.getChannels);
exports.default = router;
