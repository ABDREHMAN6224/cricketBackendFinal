import expressAsyncHandler from "express-async-handler";
import db from "../connection/connection.js";
export const createCountry = expressAsyncHandler(async (req, res) => {
  try {
    const { country } = req.body;
    //check if country name already exists
    const found = await db.query("SELECT * FROM country WHERE country=$1", [
      country,
    ]);
    if (found.rows.length > 0) {
      res.status(400).json({ message: "Country already exists" });
    }
    
    const result = await db.query(
      "INSERT INTO country(country) VALUES ($1)",
      [country]
    );
    res.status(200).json(result.rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});
export const getAllCountries = expressAsyncHandler(async (req, res) => {
  try {
    const result = await db.query("SELECT * FROM country");
    res.status(200).json(result.rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});
export const updateCountry = expressAsyncHandler(async (req, res) => {
    try {
        const { countryid } = req.params;
        const { country } = req.body;
        //check if country name already exists
        const found = await db.query('SELECT * FROM country WHERE country=$1', [country]);
        if (found.rows.length > 0) {
            res.status(400).json({ message: "Country already exists" })
        }
        const result = await db.query('UPDATE country SET country=$1 WHERE countryid=$2', [country, countryid]);
        res.status(200).json(result.rows);

    } catch (error) {
        res.status(500).json({ message: error.message })
    }
}
)
export const deleteCountry = expressAsyncHandler(async (req, res) => {
    try {
        const { countryid } = req.params;
        const result = await db.query('DELETE FROM country WHERE countryid=$1', [countryid]);
        res.status(200).json(result.rows);
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
}
)