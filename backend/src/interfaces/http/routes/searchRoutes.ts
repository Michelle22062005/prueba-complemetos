import { Router } from "express";
import { searchMessages } from "../controllers/searchController";
import { authenticate } from "../middleware/auth";

const router = Router();

router.get(
  "/search/messages",
  authenticate,
  searchMessages
);

export default router;