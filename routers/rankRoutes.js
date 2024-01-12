import express from "express"
import { getBattingRanks, getBowlingRanks, getOdiRanks, getRounderRanks, getT20Ranks, getTestRanks, getTop3Players, getTop3Teams, updatePlayerRank, updateTeamRank } from "../controllers/rankController.js";
import { isAuthenticatedForPlayers, isAuthenticatedForTeam } from "../middlewares/auth.js";
const router = express.Router();
router.get("/bowlingranks", getBowlingRanks);
router.get("/battingranks", getBattingRanks);
router.get("/allrounderranks", getRounderRanks);
router.get("/t20iranks", getT20Ranks);
router.get("/odiranks", getOdiRanks);
router.get("/testranks", getTestRanks);
router.get("/getTopPlayers",isAuthenticatedForPlayers,getTop3Players);
router.get("/getTopTeams",isAuthenticatedForTeam,getTop3Teams);
router.put("/updatePlayerRank/:playerid",isAuthenticatedForPlayers, updatePlayerRank);
router.put("/updateTeamRank/:teamid",isAuthenticatedForTeam,updateTeamRank);
export default router