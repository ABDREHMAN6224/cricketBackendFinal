import express from "express"
import { getAllBatsman, getSingleBatsman } from "../controllers/batsmanContoller.js";
import { isAuthenticatedForPlayers } from "../middlewares/auth.js";
const router = express.Router();
router.get("/all",getAllBatsman);
router.get("/batsman/:playerId",getSingleBatsman);


export default router