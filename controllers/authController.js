import expressAsyncHandler from "express-async-handler";
import db from "../connection/connection.js";
import jwt from "jsonwebtoken";
import bcrypt from "bcrypt"

export const getLengths = expressAsyncHandler(async (req, res) => {
    try {
        //find number of records in each table
        const players=await db.query("SELECT COUNT(*) FROM player");
        const teams=await db.query("SELECT COUNT(*) FROM team");
        const matches=await db.query("SELECT COUNT(*) FROM match");
        const tournaments=await db.query("SELECT COUNT(*) FROM tournament");
        const stadiums=await db.query("SELECT COUNT(*) FROM location");
        const umpires=await db.query("SELECT COUNT(*) FROM umpire");
        const captains=await db.query("SELECT COUNT(*) FROM captain");
        const coaches=await db.query("SELECT COUNT(*) FROM coach");
        const keepers=await db.query("SELECT COUNT(*) FROM wicketkeeper");
        const countries=await db.query("SELECT COUNT(*) FROM country");
        //make object to send
        const lengths={
            players:players.rows[0].count,
            teams:teams.rows[0].count,
            matches:matches.rows[0].count,
            tournaments:tournaments.rows[0].count,
            stadiums:stadiums.rows[0].count,
            umpires:umpires.rows[0].count,
            captains:captains.rows[0].count,
            coaches:coaches.rows[0].count,
            keepers:keepers.rows[0].count,
            countries:countries.rows[0].count
        }
        //send object
        res.status(200).json(lengths);
    } catch (error) {
        console.log(error);
        res.status(500).json({message:error.message});
        
    }
});

export const registerUser = expressAsyncHandler(async (req, res) => {
    try {
        //get data from req body
        const { username,role,userpicpath, password } = req.body;
        //check if user exists
        const userExists = await db.query("SELECT * FROM users WHERE username=$1", [username]);
        if (userExists.rows.length > 0) {
            res.status(400).json({ message: "User already exists" });
        }
        //hash password
        const salt=bcrypt.genSaltSync(10);
        const hash=bcrypt.hashSync(password,salt);
        //insert user into database
        const user = await db.query("INSERT INTO users (username,userrole,userpicpath,password,datejoined,hashed_password) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *", [username,role.toLowerCase(),userpicpath,password,new Date(),hash]);

        //send user details
        // res.json({ message: "User created" });
        res.status(201).json(user.rows[0]);
    } catch (error) {
        console.log(error);
        res.status(500).json({ message: error.message });
    }
});
export const loginUser = expressAsyncHandler(async (req, res) => {
    try {
        //get data from req body
        const { username, password } = req.body;
        //check if user exists
        const user = await db.query("SELECT * FROM users WHERE username=$1", [username]);
        if (user.rows.length === 0) {
           return res.status(400).json({ message: "User does not exist" });
        }
        //check if password is correct
        const isMatch=bcrypt.compare(password,user.rows[0].password);
        if(!isMatch){
            return res.status(400).json({ message: "Incorrect password" });
        }
        //send user details
        //genretae token
        let token=jwt.sign({username:user.rows[0].username},process.env.JWT_SECRET,{expiresIn:"1d"});
        let createdUser={
            ...user.rows[0],
            password:undefined,
            token
        }
        // res.json({ message: "User created" });
        user.rows[0].userrole = user.rows[0].userrole.toLowerCase();
        res.status(200).json(createdUser);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});
export const getAllUsers = expressAsyncHandler(async (req, res) => {
    try {
        //get all users
        const users = await db.query("SELECT * FROM db_user where lower(username)<>$1",[req.user?.username]);
        //send users
        res.status(200).json(users.rows);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});
export const deleteUser = expressAsyncHandler(async (req, res) => {
    try {
        //get username from req params
        const {username}=req.params;
        //delete user
        const user = await db.query("DELETE FROM users WHERE username=$1 RETURNING *", [username]);
        //send user
        //convert userrole to lowercase
        user.rows[0].userrole=user.rows[0].userrole.toLowerCase();
        res.status(200).json(user.rows[0]);
    } catch (error) {
        console.log(error);
        res.status(500).json({ message: error.message });
    }
});
export const getUser = expressAsyncHandler(async (req, res) => {
    try {
        //get username from req params
        const {username}=req.params;
        //get user
        const user = await db.query("SELECT * FROM db_user WHERE username=$1", [username]);
        //send user
        res.status(200).json(user.rows[0]);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});
export const updatePic = expressAsyncHandler(async (req, res) => {
    try {
        //get username from req params
        const {username}=req.params;
        //get user
        const user = await db.query("UPDATE users SET userpicpath=$1 WHERE username=$2 RETURNING *", [req.body.userpicpath,username]);
        //send user
        res.status(200).json(user.rows[0]);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});