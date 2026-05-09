const mongoose = require("mongoose");

const connectDB = async () => {
  try{
    if(mongoose.connect.readyState >= 1){
      return;
    }
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/hookd');
    console.log("DB ~ MongoDB connected via Mongoose");
 }  catch(error) {
    console.log("DB ~ MongoDB connction error: ",error);
    process.exit(1);
 }
};

module.exports = connectDB;