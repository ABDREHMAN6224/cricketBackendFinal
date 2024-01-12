
import express from "express"
import { addRecord, deleteRecord, getMatchScorecard, getPlayerInnings } from "../controllers/scorecardController.js";
import { isAuthenticatedForTournament, isAuthenticatedForTournamentInsertion } from "../middlewares/auth.js";
const router = express.Router();
router.get("/innings/:player_id", getPlayerInnings);
router.get("/match/:match_id", getMatchScorecard);
router.post("/add/:match_id/:player_id",isAuthenticatedForTournamentInsertion, addRecord);
router.delete("/deleteRecord/:match_id/:player_id",isAuthenticatedForTournament, deleteRecord);
export default router;