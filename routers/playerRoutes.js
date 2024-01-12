import express from "express"
import { createPlayer, deletePlayer, getAllPlayers, getPlayer, updateStats, updatePlayerPicture, updatePlayer, getPlayersWithNoTeam } from "../controllers/playerController.js";
import { isAuthenticatedForPlayers, isAuthenticatedForPlayersInsertion } from "../middlewares/auth.js";
const router = express.Router();
router.get("/player/:playerId", getPlayer);
router.post("/player/:playerId", deletePlayer)
router.post("/createPlayer",isAuthenticatedForPlayersInsertion, createPlayer);
router.get("/all", getAllPlayers);
router.put("/updateNoOfmatches/:playerId",isAuthenticatedForPlayers, updatePlayer)
router.put("updateStats/:playerId",isAuthenticatedForPlayers, updateStats)
router.put("/updateProfile/:playerId",isAuthenticatedForPlayers, updatePlayerPicture)
router.get("/playerWithNoTeam",getPlayersWithNoTeam)
export default router;