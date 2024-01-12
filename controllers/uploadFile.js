export const uploadFile = async (req, res) => {
    const urlServer = "http://localhost:3000"
    if (!req.file) {
        return res.status(404).json({ err: "no file found" })
    }
    const url = `${urlServer}/${req.file.filename}`
    return res.status(200).json({ url: url })
}
