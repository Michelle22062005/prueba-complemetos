import { Router } from "express";

import {
  getChannels,
} from "../controllers/channelController";

import {
  authenticate,
} from "../middleware/authMiddleware";

const router = Router();

router.get(
  "/",
  authenticate,
  getChannels
);

export default router;