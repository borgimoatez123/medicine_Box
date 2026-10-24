
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

LiquidCrystal_I2C lcd(0x27, 16, 2);

// LED
const int ledPin = 7;
bool ledState = false;

unsigned long previousLedMillis = 0;
const unsigned long ledInterval = 1000;

// Medicaments
const char* medicineNames[] = {
  "Paracetamol",
  "Vitamine",
  "Medicament 3"
};

const char* medicineTimes[] = {
  "08:00",
  "14:00",
  "20:00"
};

const int medicineCount =
  sizeof(medicineNames) / sizeof(medicineNames[0]);

int currentMedicine = 0;

unsigned long previousMedicineMillis = 0;
const unsigned long medicineInterval = 3000;

void setup() {
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, LOW);

  lcd.init();
  lcd.backlight();

  lcd.setCursor(0, 0);
  lcd.print("Smart Medicine");

  lcd.setCursor(0, 1);
  lcd.print("System Ready");
}

void loop() {
  unsigned long currentMillis = millis();

  // LED: ON/OFF every second
  if (currentMillis - previousLedMillis >= ledInterval) {
    previousLedMillis = currentMillis;

    ledState = !ledState;
    digitalWrite(ledPin, ledState);
  }

  // Change displayed medicine every 3 seconds
  if (currentMillis - previousMedicineMillis >= medicineInterval) {
    previousMedicineMillis = currentMillis;

    currentMedicine++;

    if (currentMedicine >= medicineCount) {
      currentMedicine = 0;
    }

    displayMedicine();
  }
}

void displayMedicine() {
  lcd.clear();

  lcd.setCursor(0, 0);
  lcd.print(medicineNames[currentMedicine]);

  lcd.setCursor(0, 1);
  lcd.print("Time: ");
  lcd.print(medicineTimes[currentMedicine]);
}
