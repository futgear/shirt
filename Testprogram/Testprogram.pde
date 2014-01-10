import processing.serial.*;
import java.util.*;

// Note the HashMap's "key" is a String and "value" is an Float
HashMap<String,Float> settings = new HashMap<String,Float>();

Serial  myPort;
int     portIndex = 0;
int     lf = 10;      // ASCII linefeed
String  inString;     // String for serial communication
 
float   temp;         // Temperature
float   dt;           // Delta
float   x_gyr;        // Gyroscope data
float   y_gyr;
float   z_gyr;
float   x_acc;        // Accelerometer data
float   y_acc;
float   z_acc;
float   x_fil;        // Filtered data
float   y_fil;
float   z_fil;

float   adc_A0, adc_A1, adc_A2, adc_A3, adc_A4, adc_A5, adc_A6, adc_A7;
float   adc_B0, adc_B1, adc_B2, adc_B3, adc_B4, adc_B5, adc_B6, adc_B7;
float   adc_C0, adc_C1, adc_C2, adc_C3, adc_C4, adc_C5, adc_C6, adc_C7;
float   adc_D0, adc_D1, adc_D2, adc_D3, adc_D4, adc_D5, adc_D6, adc_D7;

float   stepsize = 1;
int     selected_key = 0;

//------------------------------------------------------------------------------------------ 
// Setup
//------------------------------------------------------------------------------------------ 
void setup()
{
 
  // read default settings from file  
  settings = getSettingsFromFile("calibration.txt");

  // get last used portindex from settings
  portIndex = int(""+ settings.get("port") +"");
  
  // size(640, 360, P3D); 
  size(1400, 800, P3D);
  stroke(0,0,0);
  colorMode(RGB, 256); 
  println(Serial.list());
  connectPort(portIndex);
} 

//------------------------------------------------------------------------------------------ 
// connect to serial port
//------------------------------------------------------------------------------------------ 
void connectPort(int portIndex)
{
  try{
    String portName = Serial.list()[portIndex];
    println(" Connecting to -> " + Serial.list()[portIndex]);
    myPort = new Serial(this, portName, 115200);
    myPort.clear();
    myPort.bufferUntil(lf);
  }catch(Exception e){
    println("Couldn't open Serial Connection on PortIndex: " + portIndex);
  }  
}

//------------------------------------------------------------------------------------------ 
// Read settings from a textfile.
// The settings must contain "key=value" where value is a float and key is a string.
// No whitespaces allowed in the configtextfile!
//------------------------------------------------------------------------------------------ 
HashMap<String,Float> getSettingsFromFile(String filename)
{
  println("------------------------------------------");
  println("Loading settings from: "+filename);
  HashMap<String,Float> hm = new HashMap<String,Float>();
  String settings_file[] = loadStrings(filename);
  for(String setting : settings_file){
    String setting_pair[] = setting.split("=");
    if(setting_pair.length > 1){
      println(setting_pair[0]+"="+setting_pair[1]);
      hm.put(""+setting_pair[0]+"", float(setting_pair[1])) ;
    }else{
      println("Error in: "+setting_pair[0]);
    }
  }
  return hm;
}

//------------------------------------------------------------------------------------------ 
// read the serialinput
//------------------------------------------------------------------------------------------ 
void serialEvent(Serial p)
{
  inString = (myPort.readString());
  try{
    // Parse the data
    String[] dataStrings = split(inString, '#');
    for (int i = 0; i < dataStrings.length; i++) {
      String type = dataStrings[i].substring(0, 4);
      String dataval = dataStrings[i].substring(4);
      if (type.equals("DEL:")) {
        dt = float(dataval);
      } else if (type.equals("TMP:")) {
        temp = float(dataval);
      } else if (type.equals("ACC:")) {
        String data[] = split(dataval, ',');
        x_acc = float(data[0]);
        y_acc = float(data[1]);
        z_acc = float(data[2]);
      } else if (type.equals("GYR:")) {
        String data[] = split(dataval, ',');
        x_gyr = float(data[0]);
        y_gyr = float(data[1]);
        z_gyr = float(data[2]);
      } else if (type.equals("FIL:")) {
        String data[] = split(dataval, ',');
        x_fil = float(data[0]);
        y_fil = float(data[1]);
        z_fil = float(data[2]);
      } else if (type.equals("ADC:")) {
        String data[] = split(dataval, ',');

        adc_A0 = float(data[0]); //
        adc_A1 = float(data[1]); //
        adc_A2 = float(data[2]); //
        adc_A3 = float(data[3]); //
        adc_A4 = float(data[4]); //
        adc_A5 = float(data[5]); //
        adc_A6 = float(data[6]); //
        adc_A7 = float(data[7]); //

        adc_B0 = float(data[8]); //
        adc_B1 = float(data[9]); //Unter
        adc_B2 = float(data[10]); //Elle
        adc_B3 = float(data[11]); //Ober
        adc_B4 = float(data[12]); //Vor-Zurück
        adc_B5 = float(data[13]); //Hoch-Runter
        adc_B6 = float(data[14]); //
        adc_B7 = float(data[15]); //

        adc_C0 = float(data[16]); //
        adc_C1 = float(data[17]); //Unter
        adc_C2 = float(data[18]); //Elle
        adc_C3 = float(data[19]); //Ober
        adc_C4 = float(data[20]); //Vor-Zurück
        adc_C5 = float(data[21]); //Hoch-Runter
        adc_C6 = float(data[22]); //
        adc_C7 = float(data[23]); //

        adc_D0 = float(data[24]); //
        adc_D1 = float(data[25]); //Unter
        adc_D2 = float(data[26]); //Elle
        adc_D3 = float(data[27]); //Ober
        adc_D4 = float(data[28]); //Vor-Zurück
        adc_D5 = float(data[29]); //Hoch-Runter
        adc_D6 = float(data[30]); //
        adc_D7 = float(data[31]); //  
      }
      //println(dataval);
    }
  }catch(Exception e){
    println("Serial event:" + e);
  }

  try{
    //******************************** BODY CALCULATIONS ********************************
    float convertedValue = 0;

    settings.put("chest_X", 40-90-y_fil ); // +Back -Forth // radians(-x_fil) );
    settings.put("chest_Y", 0.0 ); // +RotateLeft -RotateRight // radians(-y_fil) );
    settings.put("chest_Z", -x_fil ); // +LeanLeft -LeanRight

    //----------------LINKS---------------------------------------
    //Unterarm Drehung
    convertedValue = conval(adc_B3, "forearmL_X");
    settings.put("forearmL_X", convertedValue * pow(settings.get("forearmL_X_log") , adc_B3 * settings.get("forearmL_X_exp")) );

    //Ellenbogen
    convertedValue = pow(adc_B4,pow(settings.get("forearmL_Y_log") , settings.get("forearmL_Y_exp")))/50000000000.0;
    convertedValue = conval(convertedValue, "forearmL_Y");
    settings.put("forearmL_Y", convertedValue);

    //Oberarm DrehungX
    convertedValue = conval(adc_B5, "upperarmL_X");
    settings.put("upperarmL_X", convertedValue * pow(settings.get("upperarmL_X_log") , adc_B5 * settings.get("upperarmL_X_exp")) );

    //Oberarm Vor-Zurück
    convertedValue = conval(adc_B6, "upperarmL_Y");
    settings.put("upperarmL_Y", convertedValue);

    //Oberarm Hoch-Runter
    convertedValue = conval(adc_B7, "upperarmL_Z");
    settings.put("upperarmL_Z", convertedValue );

    //----------------RECHTS----------------------------------------
    //Unterarm Drehung
    convertedValue = conval(adc_D4, "forearmR_X");
    settings.put("forearmR_X", pow(convertedValue,pow(settings.get("forearmR_X_log") , settings.get("forearmR_X_exp"))));

    //Ellenbogen
    convertedValue = pow(adc_D3,pow(settings.get("forearmR_Y_log") , settings.get("forearmR_Y_exp")))/50000000000.0;
    convertedValue = conval(convertedValue, "forearmR_Y");
    settings.put("forearmR_Y", convertedValue);
    
    /*
    for(i=0;i<messpunkte;i++){
      delay(1000);
      messpunkt[i]=(range/messpunkte)*i;
      messwert[i]=adc_D3;
    }
    */
    
    //Oberarm Drehung
    convertedValue = conval(adc_D2, "upperarmR_X");
    settings.put("upperarmR_X", convertedValue * pow(settings.get("upperarmR_X_log") , adc_D2 * settings.get("upperarmR_X_exp")) );

    //Oberarm Vor-Zurück
    convertedValue = conval(adc_D1, "upperarmR_Y");
    settings.put("upperarmR_Y", convertedValue);

    //Oberarm Hoch-Runter
    convertedValue = conval(adc_D0, "upperarmR_Z");
    settings.put("upperarmR_Z", convertedValue );
  }catch (Exception e) {
    println("Bodycalculation:" + e);
  }
}

//------------------------------------------------------------------------------------------ 
// Write settings to a textfile.
//------------------------------------------------------------------------------------------ 
Boolean setSettingsToFile(HashMap<String,Float> hm, String filename)
{
  ArrayList settings_keys = new ArrayList(settings.keySet());
  Collections.sort(settings_keys);
  
  String[] settings_string = new String[hm.size()];
  for(int i=0; i<settings_keys.size(); i++){
    String keyname = settings_keys.get(i).toString();
    Float value = settings.get(keyname);
    settings_string[i] = keyname + "=" + value;
    print(".");
  }
  println("...done.");
  saveStrings("data/"+filename, settings_string);
  return true;
}

//------------------------------------------------------------------------------------------ 
// keyboard controls
//------------------------------------------------------------------------------------------ 
void keyPressed()
{
  String keyname="";
  float value=0;
  ArrayList settings_keys = new ArrayList(settings.keySet());
  Collections.sort(settings_keys);
  //select setting
  if(key == 'w'){
    if(selected_key<settings_keys.size()-1){
      selected_key = selected_key+1;
    }
  }
  if(key == 's'){
    if(selected_key>0){
      selected_key=selected_key-1;
    }
  }
  keyname = settings_keys.get(selected_key).toString();
  println("setting: " + keyname);
  value = settings.get(keyname);

  //changing stepsize which will be added/substracted
  if(key == '+'){
    stepsize = stepsize*10;
  }
  if(key == '-'){
    stepsize = stepsize/10;
  }

  //increase/decrease selected settings value
  if(keyCode == UP){
    settings.put(keyname, value+stepsize);
    println(keyname +" = "+ settings.get(keyname));
  }
   if(keyCode == DOWN){
    settings.put(keyname, value-stepsize);
    println(keyname +" = "+ settings.get(keyname));
  }

  if(key == '#'){
    println("Saving... ");
    setSettingsToFile(settings,"calibration.txt");
  }
  if(key == 'p'){
    println("Reconnect Port... ");
    connectPort(portIndex);
  }
  if(key == 'l'){
    println("Load Configfile... ");
    settings = getSettingsFromFile("calibration.txt");
  }

  if(key == '1' || key == '2' || key == '3' || key == '4' || key == '5' || key == '6' || key == '7' || key == '8'|| key == '9'|| key == '0'){
    portIndex = int(key)-48;
    settings.put("port", float(portIndex));
    println("Setting Port Index: "+ float(portIndex));
    setSettingsToFile(settings,"calibration.txt");
    connectPort(portIndex);
  }
}

//------------------------------------------------------------------------------------------ 
// inserts red marker box onto the body for orientation clarification
//------------------------------------------------------------------------------------------ 
void insertmarker(float sphereSize)
{
  translate(0, 0, 10);
  fill(255,0,0);
  box(sphereSize/2, sphereSize/2, sphereSize/2); 
  translate(0, 0, -10);
  fill(99, 99, 99);
}

//------------------------------------------------------------------------------------------ 
// match the range and position of bodyparts to inputvalues of the arduino
//------------------------------------------------------------------------------------------ 
Float conval(Float rawvalue, String bodyPart)
{
  float bodyRange=settings.get(bodyPart+"_hwRange");
  float offset=settings.get(bodyPart+"_hwOff");
  float minvalue=settings.get(bodyPart+"_hwMin");
  float maxvalue=settings.get(bodyPart+"_hwMax");

  float adcRange = 4096;
  try{
    adcRange = maxvalue - minvalue;
  }catch(Exception e){
    println("--------------- Could not calculate hwRange "+ maxvalue +" - "+minvalue);
  }
  rawvalue = offset + (bodyRange * ((rawvalue - minvalue) / adcRange));
  return rawvalue;
}

//------------------------------------------------------------------------------------------ 
// draw the screen
//------------------------------------------------------------------------------------------ 
void draw()
{
  background(0);
  renderText();
  renderBody();
}

//------------------------------------------------------------------------------------------ 
// render the Text to the screen
//------------------------------------------------------------------------------------------ 
void renderText()
{
  textSize(24);
  int colwidth=150;
  int x_col0=400;
  int x_col1=x_col0+colwidth/3;
  int x_col2=x_col1+colwidth;
  int x_col3=x_col2+colwidth/3;
  int x_col4=x_col3+colwidth;
  int x_col5=x_col4+colwidth/3;
  int x_col6=x_col5+colwidth;
  int x_col7=x_col6+colwidth/3;
  int y_cursor=15;
  int lineheight=3;

  String accStr = " " + (int) x_acc + ", " + (int) y_acc + " ";
  String gyrStr = " " + (int) x_gyr + ", " + (int) y_gyr + " ";
  String filStr = " " + (int) x_fil + ", " + (int) y_fil + " ";

  fill(249, 250, 50);
  text("GYR:", x_col0, (height/100)*y_cursor);
  text(gyrStr, x_col1, (height/100)*y_cursor);
  fill(56, 140, 206);
  text("TMP:", x_col2, (height/100)*y_cursor);
  text(temp  , x_col3, (height/100)*y_cursor);   
  fill(83, 175, 93);
  text("ACC:", x_col4, (height/100)*y_cursor);
  text(filStr, x_col5, (height/100)*y_cursor);
  y_cursor+=lineheight;

  fill(99, 99, 99);
  text("A0: ", x_col0, (height/100)*y_cursor);
  text(adc_A0, x_col1, (height/100)*y_cursor);
  text("B0: ", x_col2, (height/100)*y_cursor);
  text(adc_B0, x_col3, (height/100)*y_cursor);
  text("C0: ", x_col4, (height/100)*y_cursor);
  text(adc_C0, x_col5, (height/100)*y_cursor);
  text("D0: ", x_col6, (height/100)*y_cursor);
  text(adc_D0, x_col7, (height/100)*y_cursor);
  y_cursor+=lineheight;
  text("A1: ", x_col0, (height/100)*y_cursor);
  text(adc_A1, x_col1, (height/100)*y_cursor);
  text("B1: ", x_col2, (height/100)*y_cursor);
  text(adc_B1, x_col3, (height/100)*y_cursor);
  text("C1: ", x_col4, (height/100)*y_cursor);
  text(adc_C1, x_col5, (height/100)*y_cursor);
  text("D1: ", x_col6, (height/100)*y_cursor);
  text(adc_D1, x_col7, (height/100)*y_cursor);
  y_cursor+=lineheight;
  text("A2: ", x_col0, (height/100)*y_cursor);
  text(adc_A2, x_col1, (height/100)*y_cursor);
  text("B2: ", x_col2, (height/100)*y_cursor);
  text(adc_B2, x_col3, (height/100)*y_cursor);
  text("C2: ", x_col4, (height/100)*y_cursor);
  text(adc_C2, x_col5, (height/100)*y_cursor);
  text("D2: ", x_col6, (height/100)*y_cursor);
  text(adc_D2, x_col7, (height/100)*y_cursor);
  y_cursor+=lineheight;
  text("A3: ", x_col0, (height/100)*y_cursor);
  text(adc_A3, x_col1, (height/100)*y_cursor);
  text("B3: ", x_col2, (height/100)*y_cursor);
  text(adc_B3, x_col3, (height/100)*y_cursor);
  text("C3: ", x_col4, (height/100)*y_cursor);
  text(adc_C3, x_col5, (height/100)*y_cursor);
  text("D3: ", x_col6, (height/100)*y_cursor);
  text(adc_D3, x_col7, (height/100)*y_cursor);
  y_cursor+=lineheight;
  text("A4: ", x_col0, (height/100)*y_cursor);
  text(adc_A4, x_col1, (height/100)*y_cursor);
  text("B4: ", x_col2, (height/100)*y_cursor);
  text(adc_B4, x_col3, (height/100)*y_cursor);
  text("C4: ", x_col4, (height/100)*y_cursor);
  text(adc_C4, x_col5, (height/100)*y_cursor);
  text("D4: ", x_col6, (height/100)*y_cursor);
  text(adc_D4, x_col7, (height/100)*y_cursor);
  y_cursor+=lineheight;
  text("A5: ", x_col0, (height/100)*y_cursor);
  text(adc_A5, x_col1, (height/100)*y_cursor);
  text("B5: ", x_col2, (height/100)*y_cursor);
  text(adc_B5, x_col3, (height/100)*y_cursor);
  text("C5: ", x_col4, (height/100)*y_cursor);
  text(adc_C5, x_col5, (height/100)*y_cursor);
  text("D5: ", x_col6, (height/100)*y_cursor);
  text(adc_D5, x_col7, (height/100)*y_cursor);
  y_cursor+=lineheight;
  text("A6: ", x_col0, (height/100)*y_cursor);
  text(adc_A6, x_col1, (height/100)*y_cursor);
  text("B6: ", x_col2, (height/100)*y_cursor);
  text(adc_B6, x_col3, (height/100)*y_cursor);
  text("C6: ", x_col4, (height/100)*y_cursor);
  text(adc_C6, x_col5, (height/100)*y_cursor);
  text("D6: ", x_col6, (height/100)*y_cursor);
  text(adc_D6, x_col7, (height/100)*y_cursor);
  y_cursor+=lineheight;
  text("A7: ", x_col0, (height/100)*y_cursor);
  text(adc_A7, x_col1, (height/100)*y_cursor);
  text("B7: ", x_col2, (height/100)*y_cursor);
  text(adc_B7, x_col3, (height/100)*y_cursor);
  text("C7: ", x_col4, (height/100)*y_cursor);
  text(adc_C7, x_col5, (height/100)*y_cursor);
  text("D7: ", x_col6, (height/100)*y_cursor);
  text(adc_D7, x_col7, (height/100)*y_cursor);
  y_cursor+=lineheight;
  y_cursor+=lineheight;
  text("forearmR_Y: ", x_col5, (height/100)*y_cursor);
  text(settings.get("forearmR_Y"), x_col7, (height/100)*y_cursor);
  y_cursor+=lineheight;
  text("forearmL_Y: ", x_col5, (height/100)*y_cursor);
  text(settings.get("forearmL_Y"), x_col7, (height/100)*y_cursor);
}

//------------------------------------------------------------------------------------------ 
// render the 3D-model to the screen
//------------------------------------------------------------------------------------------ 
void renderBody()
{

  float sphereSize=10;
  
  //belly
  translate(width/2, height/1.5, 0);
  box(settings.get("belly_W"), settings.get("belly_H"), settings.get("belly_D")); 

  //chest-Helper
  translate(0, -(settings.get("belly_H")/2), 0);
  sphere(sphereSize); 
  rotateX(radians(settings.get("chest_X")));
  rotateY(radians(settings.get("chest_Y")));
  rotateZ(radians(settings.get("chest_Z")));

  translate(0, -(settings.get("chest_H")/2), 0);
  box(settings.get("chest_W"), settings.get("chest_H"), settings.get("chest_D")); 
  
  pushMatrix();
  
  //Left Shoulder
  translate(settings.get("chest_W")/2, -(settings.get("chest_H")/2), 0);
    //Y-BOX
  box(sphereSize, sphereSize, sphereSize); 
  insertmarker(sphereSize);
  translate(sphereSize*2, 0, 0);
  rotateY(-radians(settings.get("upperarmL_Y")));
    //Z-BOX
  box(sphereSize, sphereSize, sphereSize); 
  insertmarker(sphereSize);
  translate(sphereSize*2, 0, 0);
  rotateZ(radians(settings.get("upperarmL_Z")));
    //X-BOX
  box(sphereSize, sphereSize, sphereSize); 
  insertmarker(sphereSize);
  translate(sphereSize*2, 0, 0);
  rotateX(radians(settings.get("upperarmL_X")));
  
  //Left Upperarm
  translate((settings.get("upperarm_W")/2), 0, 0);
  box(settings.get("upperarm_W"), settings.get("upperarm_H"), settings.get("upperarm_D")); 
  insertmarker(sphereSize);

  //Left Ellbow
  translate(settings.get("upperarm_W")/2, 0, 0);
  sphere(sphereSize); 
  rotateY(radians(settings.get("forearmL_Y"))); 
  //Left Forearm
  translate((settings.get("forearm_W")/2), 0, 0);
  box(settings.get("forearm_W"), settings.get("forearm_H"), settings.get("forearm_D")); 
  insertmarker(sphereSize);
  rotateX(radians(settings.get("forearmL_X")));

  //Left Handgelenk
  translate(settings.get("forearm_W")/2, 0, 0);
  sphere(sphereSize); 
  rotateY(radians(settings.get("handL_Y")));
  rotateZ(radians(settings.get("handL_Z")));
  //Left Hand
  translate(settings.get("hand_W")/2, 0, 0);
  box(settings.get("hand_W"), settings.get("hand_H"), settings.get("hand_D")); 
  insertmarker(sphereSize);
  
  popMatrix();
  
  //Rua-Helper
  translate(-(settings.get("chest_W")/2), -(settings.get("chest_H")/2), 0);
  box(sphereSize, sphereSize, sphereSize); 
  insertmarker(sphereSize);
  translate(-(sphereSize*2), 0, 0);
  rotateY(-radians(settings.get("upperarmR_Y")));

  box(sphereSize, sphereSize, sphereSize); 
  insertmarker(sphereSize);
  translate(-(sphereSize*2), 0, 0);
  rotateZ(-radians(settings.get("upperarmR_Z")));

  box(sphereSize, sphereSize, sphereSize); 
  insertmarker(sphereSize);
  translate(-(sphereSize*2), 0, 0);
  rotateX(radians(settings.get("upperarmR_X")));
  
  //Rua
  translate(-(settings.get("upperarm_W")/2), 0, 0);
  box(settings.get("upperarm_W"), settings.get("upperarm_H"), settings.get("upperarm_D")); 
  insertmarker(sphereSize);

  //Rfa-Helper
  translate(-(settings.get("upperarm_W")/2), 0, 0);
  sphere(sphereSize); 
  rotateY(-radians(settings.get("forearmR_Y")));
  //Rfa
  translate(-(settings.get("forearm_W")/2), 0, 0);
  box(settings.get("forearm_W"), settings.get("forearm_H"), settings.get("forearm_D")); 
  insertmarker(sphereSize);
  rotateX(radians(settings.get("forearmR_X")));

  //Rh
  translate(-(settings.get("forearm_W")/2), 0, 0);
  sphere(sphereSize); 
  rotateY(-radians(settings.get("handR_Y")));
  rotateZ(-radians(settings.get("handR_Z")));
  //Rh
  translate(-(settings.get("hand_W")/2), 0, 0);
  box(settings.get("hand_W"), settings.get("hand_H"), settings.get("hand_D")); 
  insertmarker(sphereSize);

  stroke(255);
}

//------------------------------------------------------------------------------------------ 
//This is for numbers not bouncing around in screen position if a digit is added or substracted
//------------------------------------------------------------------------------------------ 
/*String stillnum(float num){
  String numstring;
    num= num*100;
    num= floor(num);
    num=num/100;
    numstring=""+int(num)+"";
    if (numstring.length() == 1){
      numstring = "___" + numstring;
    }else if (numstring.length() == 2){
      numstring="__"+numstring;
    }else if (numstring.length() == 3){
      numstring="_"+numstring;
    }
  return numstring;
}*/
