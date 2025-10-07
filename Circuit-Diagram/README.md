
|            **Component**            |   **Pin Label**  | **Connected To (ESP32 Pin)** |    **Description / Function**    |
| :---------------------------------: | :--------------: | :--------------------------: | :------------------------------: |
|          **DHT22 Sensor 1**         |         +        |              3V3             |        Power supply (3.3V)       |
|                                     |        Out       |              D5              |       Data output to ESP32       |
|                                     |         -        |              GND             |         Ground connection        |
|          **DHT22 Sensor 2**         |         +        |              3V3             |        Power supply (3.3V)       |
|                                     |        Out       |              D4              |       Data output to ESP32       |
|                                     |         -        |              GND             |         Ground connection        |
|   **MQ-135 (Air Quality Sensor)**   |        VCC       |              3V3             |        Power supply (3.3V)       |
|                                     |        GND       |              GND             |         Ground connection        |
|                                     |        A0        |              D34             |   Analog output signal to ESP32  |
| **HX711 (Bridge Sensor Interface)** |  3.3/3.5V Supply |              3V3             |        Power supply (3.3V)       |
|                                     |   GND - GROUND   |              GND             |         Ground connection        |
|                                     |    DATA (OUT)    |              D12             |      Data output from HX711      |
|                                     | SCK - CLOCK (IN) |              D13             |       Clock input to HX711       |
| **BH1750 (Light Intensity Sensor)** |        VCC       |              3V3             |        Power supply (3.3V)       |
|                                     |        GND       |              GND             |         Ground connection        |
|                                     |        SCL       |              D22             |      Serial clock line (I2C)     |
|                                     |        SDA       |              D21             |      Serial data line (I2C)      |
|      **ESP32 Microcontroller**      |        3V3       |               —              | Distributes power to all sensors |
|                                     |        GND       |               —              | Common ground for all components |

---

