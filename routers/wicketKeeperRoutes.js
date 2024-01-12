import express from 'express';
import { createWicketKeeper, deleteWicketKeeper, getAllWicketKeeper, getWicketKeeper, updateWicketKeeper } from '../controllers/wicketKeepercontroller.js';
import { isAuthenticatedForTeam, isAuthenticatedForTeamInsertion} from '../middlewares/auth.js';
const router = express.Router();
router.post("/createKeeper",isAuthenticatedForTeamInsertion,createWicketKeeper)
router.get("/all", getAllWicketKeeper)
router.get("/single/:player_id", getWicketKeeper)
router.put("/update/:player_id",isAuthenticatedForTeam,updateWicketKeeper)
router.delete("/keeper/:player_id",isAuthenticatedForTeam,deleteWicketKeeper)
export default router;