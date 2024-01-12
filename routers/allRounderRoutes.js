import express from "express"
import { getAllRounders, getOneAllRounder } from "../controllers/allRounderController.js";
import { isAuthenticatedForPlayers } from "../middlewares/auth.js";
const router = express.Router();
router.get("/all",getAllRounders)
router.get("/allrounder/:playerId",getOneAllRounder);

export default router;