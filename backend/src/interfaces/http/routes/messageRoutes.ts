import { Router } from "express";

import {
  getMessages,
  createMessage,
  editMessage,
  deleteMessage,
} from "../controllers/messageController";

import { authenticate } from "../middleware/auth";

const router = Router();

router.get(
  "/channels/:channelId/messages",
  authenticate,
  getMessages
);

router.post(
  "/messages",
  authenticate,
  createMessage
);

router.patch(
  "/messages/:messageId",
  authenticate,
  editMessage
);

router.delete(
  "/messages/:messageId",
  authenticate,
  deleteMessage
);

export default router;