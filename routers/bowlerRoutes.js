import express from "express"
import { getAllBolwers, getSingleBowler } from "../controllers/bowlerController.js"
const router = express.Router()
router.get("/all", getAllBolwers);
router.get("/bowler/:playerId", getSingleBowler);
export default router