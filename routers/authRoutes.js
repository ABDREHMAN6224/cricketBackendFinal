import express from "express";
import { deleteUser, getAllUsers, getLengths, getUser, loginUser, registerUser, updatePic } from "../controllers/authController.js";
import { isAdmin, isAuthenticated } from "../middlewares/auth.js";
import expressAsyncHandler from "express-async-handler";
import { spawn } from 'child_process';
import readline from 'readline';
import path from "path";
import { fileURLToPath } from "url";
import fs from "fs";
const router = express.Router();
router.get("/lengths",getLengths);
router.post("/register",registerUser);
router.post("/login",loginUser);
router.get("/all",isAdmin,getAllUsers);
router.delete("/delete/:username",isAdmin,deleteUser);
router.get("/user/:username",isAuthenticated,getUser);
router.put("/user/:username",isAuthenticated,updatePic);

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const filePathToBackup = path.join(__dirname, "backups/backup"+Date.now()+".sql");

router.post('/backup',isAdmin, (req, res) => {
    try {
        
        const { password } = req.body;
        if (!password) {
            return res.status(400).json({ message: 'Password is required' });
        }
        process.env.PGPASSWORD = password;
        const command = 'pg_dump';
        const args = [
            '-h', 'localhost',
            '-p', '5432',
            '-U', 'postgres',
            '-d', 'DBMS Cricket',
        ];
        
        const backupProcess = spawn(command, args);
        const writeStream = fs.createWriteStream(filePathToBackup);
        backupProcess.stdout.pipe(writeStream);
        backupProcess.stdin.write(`${password}\n`);
        backupProcess.stdin.end();
        
        
     backupProcess.on('error', (error) => {
        console.error(`Error: ${error.message}`);
        return res.status(500).json({error: error.message});
    });
    
    backupProcess.on('close', (code) => {
        delete process.env.PGPASSWORD; 
        if (code === 0) {
            console.log('Backup successful');
            return res.sendFile(filePathToBackup, (err) => {
                if (err) {
                    console.error(`Error sending file: ${err.message}`);
                    return res.status(500).json({error: err.message});
                } else {
                    console.log('File sent to frontend');
                }
            });
        } else {
            console.error(`Backup process exited with code ${code}`);
            
            return res.status(500).json({
                message: 'Backup process exited with code ${code}',
            });
            
        }
    });
} catch (error) {
    res.status(500).json({ message: error.message });
}
});

export default router;