"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const searchController_1 = require("../controllers/searchController");
const auth_1 = require("../middleware/auth");
const router = (0, express_1.Router)();
router.get("/search/messages", auth_1.authenticate, searchController_1.searchMessages);
exports.default = router;
