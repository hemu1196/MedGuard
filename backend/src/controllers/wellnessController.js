const WaterIntake = require('../models/WaterIntake');
const BmiHistory = require('../models/BmiHistory');
const User = require('../models/User');

const getTodayDateString = () => {
  const d = new Date();
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const getWaterIntake = async (req, res) => {
  try {
    const todayStr = req.query.date || getTodayDateString();
    let record = await WaterIntake.findOne({ userId: req.userId, date: todayStr });

    if (!record) {
      record = new WaterIntake({
        userId: req.userId,
        date: todayStr,
        targetMl: 2000,
        consumedMl: 0,
        logs: [],
      });
      await record.save();
    }

    return res.status(200).json({
      success: true,
      waterIntake: record,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch water intake record.',
    });
  }
};

const logWaterIntake = async (req, res) => {
  try {
    const { amountMl, date, targetMl } = req.body;
    const todayStr = date || getTodayDateString();

    let record = await WaterIntake.findOne({ userId: req.userId, date: todayStr });
    if (!record) {
      record = new WaterIntake({
        userId: req.userId,
        date: todayStr,
        targetMl: targetMl || 2000,
        consumedMl: 0,
        logs: [],
      });
    }

    if (targetMl) {
      record.targetMl = Number(targetMl);
    }

    if (amountMl) {
      const addedAmount = Number(amountMl);
      record.consumedMl += addedAmount;
      const now = new Date();
      const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
      record.logs.push({ time: timeStr, amountMl: addedAmount, timestamp: now });
    }

    await record.save();

    return res.status(200).json({
      success: true,
      message: 'Water intake updated successfully.',
      waterIntake: record,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to update water intake.',
    });
  }
};

const getBmiHistory = async (req, res) => {
  try {
    const history = await BmiHistory.find({ userId: req.userId }).sort({ calculatedAt: -1 }).limit(30);
    return res.status(200).json({
      success: true,
      history,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch BMI history.',
    });
  }
};

const calculateBmi = (weightKg, heightCm) => {
  const heightM = heightCm / 100;
  const bmi = Number((weightKg / (heightM * heightM)).toFixed(1));
  let category = 'Normal';
  if (bmi < 18.5) category = 'Underweight';
  else if (bmi >= 18.5 && bmi <= 24.9) category = 'Normal weight';
  else if (bmi >= 25.0 && bmi <= 29.9) category = 'Overweight';
  else category = 'Obese';

  return { bmi, category };
};

const saveBmiRecord = async (req, res) => {
  try {
    const { weightKg, heightCm } = req.body;

    if (!weightKg || !heightCm) {
      return res.status(400).json({
        success: false,
        message: 'Weight (kg) and Height (cm) are required.',
      });
    }

    const { bmi, category } = calculateBmi(Number(weightKg), Number(heightCm));

    const bmiRecord = new BmiHistory({
      userId: req.userId,
      weightKg: Number(weightKg),
      heightCm: Number(heightCm),
      bmi,
      category,
      calculatedAt: new Date(),
    });

    await bmiRecord.save();

    // Update user height/weight in User profile
    await User.findByIdAndUpdate(req.userId, {
      $set: { weightKg: Number(weightKg), heightCm: Number(heightCm) },
    });

    return res.status(201).json({
      success: true,
      message: 'BMI calculated and recorded.',
      record: bmiRecord,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to save BMI record.',
    });
  }
};

module.exports = {
  getWaterIntake,
  logWaterIntake,
  getBmiHistory,
  saveBmiRecord,
};
