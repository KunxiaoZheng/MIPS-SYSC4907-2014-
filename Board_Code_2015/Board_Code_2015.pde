//#include <WiFiShieldOrPmodWiFi.h>
//#include <DNETcK.h>
//#include <DWIFIcK.h>
#include <pt.h>
#include <chipKITEthernet.h>


//--------------------------------------------------------------------------------//
//-----------------------------Network Data Configuration----------------------------//
//--------------------------------------------------------------------------------//
typedef enum
{
  NONE = 0,
  INITIALIZE,
  LISTEN,
  ISLISTENING,
  AVAILABLECLIENT,
  ACCEPTCLIENT,
  READ,
  PROCESSREAD,
  WRITE,
  CLOSE,
  EXIT,
  DONE
} 
STATE;

// network configuration.  gateway and subnet are optional.

// the media access control (ethernet hardware) address for the shield:
byte mac[] = { 
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };  
//the IP address for the shield:
byte ip[] = { 
  169, 254, 1, 0 };    
// the router's gateway address:
byte gateway[] = { 
  169, 254, 1, 0 };
// the subnet:
byte subnet[] = { 
  255, 255, 0, 0 };

//use port 44400
//unsigned short portServer = DNETcK::iPersonalPorts44 + 400;
unsigned short portServer = 44400;


Server server = Server(portServer);
  
Server opticalServer = Server(200);


STATE state = INITIALIZE;

unsigned tStart = 0;
unsigned tWait = 5000;

//TcpServer tcpServer;
//TcpClient tcpClient;

//initialize all of the buffers and counters that are going to be used
byte rgbRead[512];
byte ReadQueue[512];
byte rgbWrite[512];
char buffer[512];
int cbRead = 0;
int count = 0;

//DNETcK::STATUS status;
//--------------------------------------------------------------------------------//
//-------------------------End of Network data Configuration-------------------------//
//--------------------------------------------------------------------------------//



//--------------------------------------------------------------------------------//
//-----------------------------BUG data Configuration-----------------------------//
//--------------------------------------------------------------------------------//
static struct pt pt1, pt2,pt3;

int PWMvalue = 180;
int OEvalue = 0;
int RELAYvalue = 0;
int DIRvalue = 0;
int steps = 0;

int bitsReceived = 0;
int numBitsPerCommand = 6;


//JA - Upper Bank
//use for analog input of potentiometer
const int PM = 0;

//use as a voltage reference for potentiometer
const int PMVR = 1;

//JA - Lower Bank
//use for relay or drive motor enable
const int RELAY = 4;

//use for output enable of stepper motor
const int OE = 5; 

//use for direction of stepper motor
const int DIR = 6;

//JD - Lower Bank
//use for PWM of drive motor
const int PWM1 = 28;  

//use for clock of stepper motor
const int CLOCK = 29; 

//ise for LED to know the status of the board 
const int LED1 = 51;
const int LED2 = 52;
const int LED3 = 53;
const int LED4 = 54; 

//pin used for read optical sensor value
const int Right_Opt_One = 25;
const int Right_Opt_Two = 36;
//const int Left_Opt_One = 2;
//const int Left_Opt_Two = 2;

//value read from the optical sensor
boolean OPT_VAL = false;
boolean OPT_VAL2 = false;

//pin used for optical sensor's testing LED
const int OPT_LED = 3;

//current quad phase encoder state
volatile int encoderState=0;

//last quad phase encoder state
volatile int encoderLastState=0;

//the direction of the wheel
volatile bool right_wheel_Forward=true;


volatile bool right_in_state = true;
volatile bool right_out_state = true;
volatile int right_in_debouncing=0;
volatile int right_out_debouncing=0;
volatile bool right_in_past=false;
volatile bool right_out_past=false;

//the direction of the wheel
volatile bool left_wheel_Forward=true;


volatile bool left_in_state = true;
volatile bool left_out_state = true;
volatile int left_in_debouncing=0;
volatile int left_out_debouncing=0;
volatile bool left_in_past=false;
volatile bool left_out_past=false;
volatile bool in_read=false;
volatile bool out_read=false;

volatile int rightVelocity;
volatile int rightStateStart;
volatile int rightStateEnd;
//----------------------------------------------------------------------------------//
//---------------------------End of BUG data Configuration--------------------------//
//----------------------------------------------------------------------------------//

//turn external LED on and off according to the optical sensor value
void externalLED(boolean state){
  if(state){
    digitalWrite(OPT_LED,HIGH);
  }
  else{
    digitalWrite(OPT_LED,LOW);
  }	
}

void setup(){

  // initialize the ethernet device
  Ethernet.begin(mac, ip);

  // start listening for clients
  server.begin();
  opticalServer.begin();

  //initialize the two threads needed for communication and running BUG
  PT_INIT(&pt1);
  PT_INIT(&pt2);

  //setup all of the ports that is going to be used either as input or output
  pinMode(RELAY,OUTPUT);
  pinMode(PWM1,OUTPUT);
  pinMode(OE,OUTPUT);
  pinMode(DIR,OUTPUT);
  pinMode(CLOCK,OUTPUT);
  pinMode(PMVR,OUTPUT);
  pinMode(PM, INPUT);
  pinMode(LED1,OUTPUT);
  pinMode(LED2,OUTPUT);
  pinMode(LED3,OUTPUT);
  pinMode(LED4,OUTPUT);
  pinMode(Right_Opt_One,INPUT);
  pinMode(Right_Opt_Two,INPUT);
  //pinMode(Left_Opt_One,INPUT);
  // pinMode(Left_Opt_Two,INPUT);
  pinMode(OPT_LED,OUTPUT);

  //initialize the value for RELAY, OE, PMVR and PWM1
  //so that BUG does not move
  digitalWrite(RELAY, LOW);
  digitalWrite(OE, HIGH);
  digitalWrite(PMVR, HIGH);
  analogWrite(PWM1, PWMvalue);

  for(int i = 0; i < sizeof(ReadQueue); i++){
    ReadQueue[i] = 0;
  }

  centerWheel();
 
  //read the optical sensor value and change the LED state
  //OPT_VAL=digitalRead(Right_Opt_One);
  //OPT_VAL=digitalRead(Right_Opt_Two);
  externalLED(right_wheel_Forward);

  attachInterrupt(EXT_INT0, right_in_ISR2, RISING); 
  attachInterrupt(EXT_INT1, right_out_ISR2, RISING); 
  Serial.begin(9600); //added
}

void loop(){
  //start running the two threads that will handle the communication and running BUG
  protothread1(&pt1, 100);
  protothread2(&pt2, 100);
} 



//runBUG - function
//takes a buffer as an input
//decode the buffer value to know what is the value of OE, DIR, RELAY and PWM respectively
void runBUG(byte rgbRead[]){

  //command format [], [],  [],    [],[],[]
  //               OE, DIR, RELAY, PWM
  OEvalue = int(char(rgbRead[0]) - 48);
  DIRvalue = int(char(rgbRead[1]) - 48);
  RELAYvalue = int(char(rgbRead[2]) - 48);
  PWMvalue = int(char(rgbRead[3]) - 48)*100 + int(char(rgbRead[4]) - 48)*10 + int(char(rgbRead[5]) - 48);       

  if((RELAYvalue == 1) && (PWMvalue < 120)){
    digitalWrite(RELAY, HIGH);
    analogWrite(PWM1, 120);
  }
  else if((RELAYvalue == 1) && (PWMvalue > 227)){
    digitalWrite(RELAY, HIGH);
    analogWrite(PWM1, 227);
  }
  else if((RELAYvalue == 1) && (120 < PWMvalue < 227)){
    digitalWrite(RELAY,HIGH);
    analogWrite(PWM1, PWMvalue);    
  }
  else{
    digitalWrite(RELAY, LOW);
    analogWrite(PWM1, PWMvalue);
  }
  digitalWrite(OE, HIGH);   //taken out
  steps = analogRead(PM);
  if((steps > 320) && (DIRvalue == 1) && (OEvalue == 1)){  //turn left
    //enable the stepper motor
    digitalWrite(OE, HIGH);//added
    digitalWrite(DIR, HIGH);
    analogWrite(CLOCK, 127);
    delay(10);
    steps = analogRead(PM);   
  }
  else if((steps < 975) && (DIRvalue == 0) && (OEvalue == 1)){  //turn right
    //enable the stepper motor
    digitalWrite(OE, HIGH);//added
    digitalWrite(DIR, LOW);
    analogWrite(CLOCK, 127);
    delay(10);
    steps = analogRead(PM);
  }
  else if((DIRvalue == 0) && (OEvalue == 0) && (RELAYvalue == 0)){
      centerWheel();
  }
  else if(OE == 0){   //turn stepper motor off ##ADDED THIS TO STOP IT FROM TURNING
    digitalWrite(OE, LOW);
    steps = analogRead(PM);
  }
  else{
    analogWrite(CLOCK, 0);
  }
}

//Read the value of potentiometer and use it to center the motor
void centerWheel(){
    steps = analogRead(PM);
    if(steps < 655){
      while(steps < 655){
        digitalWrite(DIR, LOW);
        analogWrite(CLOCK, 127);
        steps = analogRead(PM);
      }
    }
    else if(steps > 620){
      while(steps > 620){
        digitalWrite(DIR, HIGH);
        analogWrite(CLOCK, 127);
        steps = analogRead(PM);
      }
    }
    analogWrite(CLOCK, 0);
}

//lightLED - function
//takes 4 int input
//set the LED based on the value if 1 or 0
void lightLED(int valueLED1, int valueLED2, int valueLED3, int valueLED4){
  if(valueLED1 == 1){
    digitalWrite(LED1, HIGH);
  }
  else{
    digitalWrite(LED1, LOW);
  }

  if(valueLED2 == 1){
    digitalWrite(LED2, HIGH);
  }
  else{
    digitalWrite(LED2, LOW);
  }

  if(valueLED3 == 1){
    digitalWrite(LED3, HIGH);
  }
  else{
    digitalWrite(LED3, LOW);
  }

  if(valueLED4 == 1){
    digitalWrite(LED4, HIGH);
  }
  else{
    digitalWrite(LED4, LOW);
  }
}

//calculating the direction of retation for the wheel
void rightWheelDirection(){
  if((right_in_state)&&(!right_out_state)){
    if((!right_in_past)&&(!right_out_past)){
      right_wheel_Forward=false;
    }
    else{
      right_wheel_Forward=true;
    }
  }
  else if((!right_in_state)&&(!right_out_state)){
    if((right_in_past)&&(!right_out_past)){
      right_wheel_Forward=true;
    }
    else{
      right_wheel_Forward=false;
    }
  }
  else if((right_in_state&&right_out_state)){
    if((!right_in_past)&&(right_out_past)){
      right_wheel_Forward=true;
    }
    else{
      right_wheel_Forward=false;
    }
  }
  else{
    if((!right_in_past)&&(!right_out_past)){
      right_wheel_Forward=true;
    }
    else{
      right_wheel_Forward=false;
    }
  }
  externalLED(right_wheel_Forward); 
  right_in_past=right_in_state;
  right_out_past=right_out_state;
}


void rightWheelVelocity(){
  rightVelocity=(21/(rightStateEnd-rightStateStart));
 //Serial.println(rightVelocity);
  if(rightVelocity<500){//the units for the rightVelocity is mm/ms
    rightVelocity=0;
  }
  
  rightStateStart=rightStateEnd;
  sendDataToControl();
  //Serial.println(rightVelocity);
}

void sendDataToControl(){
  Client opticalClient = opticalServer.available();
  if(opticalClient.available()){
    opticalServer.print(rightVelocity);
  }
}


void right_in_ISR()
{
  if(millis()-right_in_debouncing>10){
    right_in_debouncing=millis();
    right_in_state=digitalRead(Right_Opt_One);
    rightWheelDirection();
    rightStateEnd=right_in_debouncing;
    rightWheelVelocity();
    delayMicroseconds(100);
    attachInterrupt(EXT_INT0, right_in_ISR2, RISING);
  }
} 
void right_in_ISR2()
{
  if(millis()-right_in_debouncing>10){
    right_in_debouncing=millis();
    right_in_state=digitalRead(Right_Opt_One); 
    rightWheelDirection();
    rightStateEnd=right_in_debouncing;
    rightWheelVelocity();
    delayMicroseconds(100);
    attachInterrupt(EXT_INT0, right_in_ISR, FALLING);
  }
} 


void right_out_ISR()
{
  if(millis()-right_out_debouncing>10){
    right_out_debouncing=millis();
    right_out_state=digitalRead(Right_Opt_Two);
    rightWheelDirection();
    rightStateEnd=right_out_debouncing;
    rightWheelVelocity();
    delayMicroseconds(100);
    attachInterrupt(EXT_INT1, right_out_ISR2, RISING);
  }
} 
void right_out_ISR2()
{
  if(millis()-right_out_debouncing>10){
    right_out_debouncing=millis();
    right_out_state=digitalRead(Right_Opt_Two);
    rightWheelDirection();
    rightStateEnd=right_out_debouncing;
    rightWheelVelocity();
    delayMicroseconds(100);
    attachInterrupt(EXT_INT1, right_out_ISR, FALLING);
  }
} 

//calculating the direction of retation for the wheel
void leftWheelDirection(){
  if((left_in_state)&&(!left_out_state)){
    if((!left_in_past)&&(!left_out_past)){
      left_wheel_Forward=false;
    }
    else{
      left_wheel_Forward=true;
    }
  }
  else if((!left_in_state)&&(!left_out_state)){
    if((left_in_past)&&(!left_out_past)){
      left_wheel_Forward=true;
    }
    else{
      left_wheel_Forward=false;
    }
  }
  else if((left_in_state&&left_out_state)){
    if((!left_in_past)&&(left_out_past)){
      left_wheel_Forward=true;
    }
    else{
      left_wheel_Forward=false;
    }
  }
  else{
    if((!left_in_past)&&(!left_out_past)){
      left_wheel_Forward=true;
    }
    else{
      left_wheel_Forward=false;
    }
  }
  //externalLED(left_wheel_Forward); 
  left_in_past=left_in_state;
  left_out_past=left_out_state;
}



void left_in_ISR()
{
  if(millis()-left_in_debouncing>10){
    left_in_debouncing=millis();
    left_in_state=true;
    leftWheelDirection();
    delayMicroseconds(100);
    attachInterrupt(EXT_INT2, left_in_ISR2, RISING);
  }
} 
void left_in_ISR2()
{
  if(millis()-left_in_debouncing>10){
    left_in_debouncing=millis();
    left_in_state=false; 
    leftWheelDirection();
    delayMicroseconds(100);
    attachInterrupt(EXT_INT2, left_in_ISR, FALLING);
  }
} 


void left_out_ISR()
{
  if(millis()-left_out_debouncing>10){
    left_out_debouncing=millis();
    left_out_state=true;
    leftWheelDirection();
    delayMicroseconds(100);
    attachInterrupt(EXT_INT3, left_out_ISR2, RISING);
  }
} 
void left_out_ISR2()
{
  if(millis()-left_out_debouncing>10){
    left_out_debouncing=millis();
    left_out_state=false;
    leftWheelDirection();
    delayMicroseconds(100);
    attachInterrupt(EXT_INT3, left_out_ISR, FALLING);
  }
} 

//thread 1 that handles how the BUG should run, it calls the runBUG function
static int protothread1(struct pt *pt, int interval){
  static unsigned long timestamp = 0;
  PT_BEGIN(pt);
  while(1){
    PT_WAIT_UNTIL(pt, millis() - timestamp > interval);
    timestamp = millis();
    //!!!!!!!!!!!!!!!!!!!!!!!!!
    //commented out the runBUG function to see if it is causing issues in the bug.        
    //!!!!!!!!!!!!!!!!!!!!!!!!!
    runBUG(ReadQueue);
  }
  PT_END(pt);
}

//thread 2 that handles the communication of BUG
static int protothread2(struct pt *pt, int interval){
  
  
  static unsigned long timestamp = 0;
  PT_BEGIN(pt);

  //Serial.print("Waiting for connection");
  //Serial.println("Ready for communication");
  while(1){
    PT_WAIT_UNTIL(pt, millis() - timestamp > interval);
    timestamp = millis();

    Client client = server.available();
    int tempDigit = 0;

    switch(state){

      /*
            *   Redundant state at the moment
       */
    case INITIALIZE:
      state = READ;
      break;

      /*
            *  If the client has sent anything, read it.
       */
    case READ:
      lightLED(0,1,0,1);

      if(client){
        if(client.available()){
          //Serial.print("Received: ");
          while(bitsReceived < numBitsPerCommand){

            // read the bytes incoming from the client:
            if(client.available()){
              char bitReceivedFromClient = client.read();

              // Fill rgbRead with the 6 bits sent 
              rgbRead[bitsReceived] = bitReceivedFromClient;
              //Serial.print(rgbRead[bitsReceived]);
              bitsReceived++;
            }
          }
          state = PROCESSREAD;
          //Serial.println("");
          //Serial.println("Command Fully Receieved");
          bitsReceived = 0;

	//else if there is no message received, disable drive motor.
        }else{
		rgbRead[2]=0;
	 	state = PROCESSREAD;
	}
		
      }

      break; 

      /* 
       *  This state checks if the received message is a command or an error and then fills the 
       *  ReadQueue to be used by the function runBUG(byte rgbRead[]) to execute the command.
       */
    case PROCESSREAD:
      if(char(rgbRead[0]) == '9'){
        // fill the ReadQueue with 0's
        for(int i = 0; i < sizeof(ReadQueue); i++){
          ReadQueue[i] = 0;
          state = CLOSE;
        }

      } 
      else if(char(rgbRead[0]) == '1' || char(rgbRead[0]) == '0'){
        for(int i = 0; i < sizeof(ReadQueue); i++){
          ReadQueue[i] = rgbRead[i];
        }
        state = WRITE;
      }

      break;

      /*
            *  Return what was sent and the angle of the wheel to the client so the client can do error checking.
       */
    case WRITE:
      //Serial.println("Writing back to Control Station");

      //populate the rgbWrite buffer to be sent to then control station
      for(int i = 0; i < sizeof(rgbWrite); i++){
        rgbWrite[i] = byte (ReadQueue[i]);
      }

      //read the value of potentiometer
      steps = analogRead(PM);

      /*
       * Sending Potentiometer to the Control Center:
       *
       * Convert the individual digits from the int 'steps' (this is a 3 digit int) into char
       * Then cast it as a byte and add the three in reverse order to the rbgWrite array to be
       * sent to the control station.
       */
      tempDigit = steps % 10;
      rgbWrite[8] = byte( (char)(((int)'0')+tempDigit));
      steps /= 10;

      tempDigit = steps % 10;
      rgbWrite[7] = byte( (char)(((int)'0')+tempDigit));
      steps /= 10;

      tempDigit = steps % 10;
      rgbWrite[6] = byte( (char)(((int)'0')+tempDigit));



      //put a NL - new line to the buffer to know that it is done
      rgbWrite[sizeof(rgbWrite)-1] = 10; 

      lightLED(1,1,0,1);

      //transmit the data back to the control station
      //server.write(rgbWrite, sizeof(rgbWrite));
      server.write(rgbWrite, sizeof(rgbWrite));
      //Serial.println("Sent to Control Center");
      //Serial.println("");


      tStart = (unsigned) millis();
      state = READ;

      break;

      /*
            *  Close the connection when the client is lost, stop the BUG, and go back to the INITIALIZE state.
       */
    case CLOSE:
      //Serial.println("Closing Client");
      digitalWrite(RELAY, LOW);
      analogWrite(CLOCK, 0);
      client.stop();
      lightLED(1,0,1,1); 
      state = INITIALIZE;

      break;    

      /*
            *   Something bad happen, just exit out of the program and clean up.
       */
    case EXIT:
      //Serial.print("EXIT ");
      //Serial.println("");
      digitalWrite(RELAY, LOW);
      analogWrite(CLOCK, 0);
      client.stop();
      lightLED(0,1,1,1);
      state = DONE;
      break;    

    default:
      state = INITIALIZE;
      break;

    }
  }
  PT_END(pt);
}



