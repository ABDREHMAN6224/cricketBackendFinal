import expressAsyncHandler from "express-async-handler";
import db from "../connection/connection.js";
import jwt from "jsonwebtoken";

export const isAuthenticatedForPlayers = expressAsyncHandler(async (req, res, next) => {
    try {
        //get token from req header
        const token = req.headers.authorization.split(" ")[1];
        //verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        // console.log(decoded);
        //get user from database
        const user = await db.query("SELECT * FROM users WHERE username=$1", [decoded.username]);
        if(user.rows.length===0){
           return res.status(404).json({message:"User not found"});
        }
        // console.log(user.rows[0]);
        //check if user is admin
        if (user.rows[0].userrole.toLowerCase() === "admin"||user.rows[0].userrole.toLowerCase() === "playermanager") {
            next();
        } else {
            res.status(401).json({ message: "Not authorized as admin" });
        }
    } catch (error) {
        res.status(401).json({ message: "Not authorized, token failed" });
    }
});
export const isAuthenticatedForPlayersInsertion = expressAsyncHandler(async (req, res, next) => {
    try {
        //get token from req header
        const token = req.headers.authorization.split(" ")[1];
        //verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        // console.log(decoded);
        //get user from database
        const user = await db.query("SELECT * FROM users WHERE username=$1", [decoded.username]);
        if(user.rows.length===0){
           return res.status(404).json({message:"User not found"});
        }
        // console.log(user.rows[0]);
        //check if user is admin
        if (user.rows[0].userrole.toLowerCase() === "admin"||user.rows[0].userrole.toLowerCase() === "playermanager"||user.rows[0].userrole.toLowerCase() === "datamanager") {
            next();
        } else {
            res.status(401).json({ message: "Not authorized as admin" });
        }
    } catch (error) {
        res.status(401).json({ message: "Not authorized, token failed" });
    }
});

export const isAuthenticatedForTournament = expressAsyncHandler(async (req, res, next) => {
    try {
        //get token from req header
        const token = req.headers.authorization.split(" ")[1];
        //verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        // console.log(decoded);
        //get user from database
        const user = await db.query("SELECT * FROM users WHERE username=$1", [decoded.username]);
        if(user.rows.length===0){
           return res.status(404).json({message:"User not found"});
        }
        // console.log(user.rows[0]);
        //check if user is admin
        if (user.rows[0].userrole.toLowerCase() === "admin"||user.rows[0].userrole.toLowerCase() === "tournamentmanager") {
            next();
        } else {
            res.status(401).json({ message: "Not authorized as admin" });
        }
    } catch (error) {
        res.status(401).json({ message: "Not authorized, token failed" });
    }
});
export const isAuthenticatedForTournamentInsertion = expressAsyncHandler(async (req, res, next) => {
    try {
        //get token from req header
        const token = req.headers.authorization.split(" ")[1];
        //verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        // console.log(decoded);
        //get user from database
        const user = await db.query("SELECT * FROM users WHERE username=$1", [decoded.username]);
        if(user.rows.length===0){
           return res.status(404).json({message:"User not found"});
        }
        // console.log(user.rows[0]);
        //check if user is admin
        if (user.rows[0].userrole.toLowerCase() === "admin"||user.rows[0].userrole.toLowerCase() === "tournamentmanager"||user.rows[0].userrole.toLowerCase() === "datamanager") {
            next();
        } else {
            res.status(401).json({ message: "Not authorized as admin" });
        }
    } catch (error) {
        res.status(401).json({ message: "Not authorized, token failed" });
    }
});



export const isAuthenticatedForTeam = expressAsyncHandler(async (req, res, next) => {
    try {
        //get token from req header
        if(!req.headers.authorization){
            return res.status(401).json({message:"Not authorized, token failed"});
        }
        const token = req.headers.authorization.split(" ")[1];
        //verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        //get user from database
        const user = await db.query("SELECT * FROM users WHERE username=$1", [decoded.username]);
        if(user.rows.length===0){
            return res.status(404).json({message:"User not found"});
        }
        //check if user is admin
        if (user.rows[0].userrole.toLowerCase() === "admin"||user.rows[0].userrole.toLowerCase() === "teammanager") {
            next();
        } else {
            res.status(401).json({ message: "Not authorized as admin" });
        }
    } catch (error) {
        console.log(error);
        res.status(401).json({ message: "Not authorized, token failed" });
    }
});
export const isAuthenticatedForTeamInsertion = expressAsyncHandler(async (req, res, next) => {
    try {
        //get token from req header
        const token = req.headers.authorization.split(" ")[1];
        //verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        // console.log(decoded);
        //get user from database
        const user = await db.query("SELECT * FROM users WHERE username=$1", [decoded.username]);
        if(user.rows.length===0){
           return res.status(404).json({message:"User not found"});
        }
        // console.log(user.rows[0]);
        //check if user is admin
        if (user.rows[0].userrole.toLowerCase() === "admin"||user.rows[0].userrole.toLowerCase() === "teammanager"||user.rows[0].userrole.toLowerCase() === "datamanager") {
            next();
        } else {
            res.status(401).json({ message: "Not authorized as admin" });
        }
    } catch (error) {
        res.status(401).json({ message: "Not authorized, token failed" });
    }
});

export const isAdmin=expressAsyncHandler(async(req,res,next)=>{
    try {
        //get token from req header
        const token = req.headers.authorization.split(" ")[1];
        //verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        //get user from database
        const user = await db.query("SELECT * FROM users WHERE username=$1", [decoded.username]);
        //check if user is admin
        if (user.rows[0].userrole.toLowerCase() === "admin") {
            req.user=user.rows[0];
            next();
        } else {
            res.status(401).json({ message: "Not authorized as admin" });
        }
    } catch (error) {
        res.status(401).json({ message: "Not authorized, token failed" });
    }  
})

//check if user token is verified
export const isAuthenticated = expressAsyncHandler(async (req, res, next) => {
    try {
        //get token from req header
        const token = req.headers.authorization.split(" ")[1];
        //verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        // console.log(decoded);
        //get user from database
        const user = await db.query("SELECT * FROM users WHERE username=$1", [decoded.username]);
        if(user.rows.length===0){
           return res.status(404).json({message:"User not found"});
        }
        // console.log(user.rows[0]);
        //check if user is admin
        if (user.rows[0].userrole.toLowerCase() === "admin"||user.rows[0].userrole.toLowerCase() === "playermanager"||user.rows[0].userrole.toLowerCase() === "tournamentmanager"||user.rows[0].userrole.toLowerCase() === "teammanager"||user.rows[0].userrole.toLowerCase() === "datamanager") {
            next();
        } else {
            res.status(401).json({ message: "Not authorized as admin" });
        }
    } catch (error) {
        res.status(401).json({ message: "Not authorized, token failed" });
    }
});