import processing.serial.*;
import java.util.Properties;
import java.io.FileInputStream;
import java.io.FileOutputStream;

final int LEVELS = 4;
final double aY = 1.622;
final double fY = -3.896;
final int delay = 50;

double v0Y = 0.0;
double vY = 0.0;
double vX = 0.0;

long timeY = 0;
long starttime = 0;
long waittillnext = 0;

Serial myPort;

class State {
  
  public static final int CALIBRY = 0;
  public static final int INGAME = 1;
  public static final int END = 2;
  
}

int state = State.CALIBRY;
boolean win = false;
boolean crash = false;

boolean forceY = false;
boolean apressed = false;
boolean dpressed = false;
double forceX = -16;

float posX = 400;
float posY = 100;

int crashAnimation = 0;
int winAnimation = 0;
int fireAnimation = 0;
int fireAnimation_left = 0;
int fireAnimation_right = 0;

PImage[] fire = new PImage[3];
PImage explosion;
PImage moon_lander;
PImage moon_lander_SCHROTT;

ArrayList<Explosion> explosions = new ArrayList<Explosion>();
ArrayList<Particle> particles = new ArrayList<Particle>();
ArrayList<Firework> fireworks = new ArrayList<Firework>();

int level = 0;
PImage[] levelMaps = new PImage[LEVELS];
PImage[] levelBlanks = new PImage[LEVELS];

String best = "Best: reset";
long totaltime = 0;

void setup() {
  printArray(Serial.list());
  if (Serial.list().length > 0) {
    String portName = Serial.list()[1];
    myPort = new Serial(this, portName, 9600);
  }
  size(800, 800);
  for (int i = 1; i <= LEVELS; i ++) {
    levelMaps[i-1] = loadImage("levels/maps/level" + i + ".png");
    levelBlanks[i-1] = loadImage("levels/blanks/level" + i + ".png");
  }
  moon_lander = loadImage("Moon_Lander.png");
  moon_lander_SCHROTT = loadImage("Moon_Lander_SCHROTT.png");
  fire[0] = loadImage("fire/Fire0.png");
  fire[1] = loadImage("fire/Fire1.png");
  fire[2] = loadImage("fire/Fire2.png");
  explosion = loadImage("explosion.png");
  PFont font = createFont("ArialMT-20", 20);
  textFont(font);
  textAlign(CENTER);
}

void draw() {

  getSerial();

  image(levelMaps[level], 0, 0);

  switch(state) {
  case State.CALIBRY:

    if (best.equals("Best: reset")) {
      getBest();
    }

    calibry();

    break;
  case State.INGAME:

    physics();

    if (collide(posX-20, posX+20, posY-15, posY+15) ||
      collide(posX-25, posX-15, posY, posY+25) ||
      collide(posX+15, posX+25, posY, posY+25)) {
      crash = true;
    }
    testPlatform();
    makeParticles();
    evaluateParticles();
    debug();

    testEnd();

    drawFlames();
    drawMoonLander();

    break;
  case State.END:

    evaluateParticles();

    drawMoonLander();

    break;
  default:
    break;
  }

  drawText();
  drawParticles();

  delay(delay);
}

void drawMoonLander() {
  if (state == State.END) {
    if (crash) {
      image(moon_lander_SCHROTT, posX-moon_lander.width/2, posY-moon_lander.height/2+5);
      if (crashAnimation < 20) {
        crashAnimation++;
        explosions.add(new Explosion((int)posX+((int)random(40)-20), (int)posY+((int)random(40)-20)));
      }
    } else {
      image(moon_lander, posX-moon_lander.width/2, posY-moon_lander.height/2+5);
    }
  } else {
    image(moon_lander, posX-moon_lander.width/2, posY-moon_lander.height/2+5);
  }
}

void calibry() {
  fill(255);
  if (forceX == -16) {
    text("Not ready!", posX, posY);
  } else {
    if (forceX != 0) { 
      text("Calibry: " + forceX, posX, posY);
    } else {
      timeY = 1500;
      posY = 0;
      starttime = millis();
      state = State.INGAME;
    }
  }
}

void testEnd() {
  if (win || crash) {
    state = State.END;
    totaltime = millis()-starttime;
    waittillnext = millis() + 1000;
    if (win) {
      Properties prop = new Properties();
      InputStream input = null;
      try {
        input = new FileInputStream(sketchPath() + "/stats.properties");
        prop.load(input);
        input.close();
        if (prop.containsKey("Level" + (level+1))) {
          long best = Long.parseLong(prop.getProperty("Level" + (level+1)));
          if (totaltime < best) {
            prop.setProperty("Level" + (level+1), "" + totaltime);
            OutputStream out = new FileOutputStream(sketchPath() + "/stats.properties");
            prop.store(out, null); 
            out.close();
          }
        } else {
          prop.setProperty("Level" + (level+1), "" + totaltime);
          OutputStream out = new FileOutputStream(sketchPath() + "/stats.properties");
          prop.store(out, null); 
          out.close();
        }
      } 
      catch (IOException ex) {
        ex.printStackTrace();
      } 
      finally {
        if (input != null) {
          try {
            input.close();
          } 
          catch (IOException e) {
            e.printStackTrace();
          }
        }
      }
    }
  }
}

void debug() {
  textAlign(CENTER);
  if (vY <= 0.7) {
    fill(0, 255, 0);
  } else {
    fill(255);
  }
  text("vY: " + String.format("%.3f", vY), posX, posY-45);
  if (vX <= 0.7 && vX >= -0.7) {
    fill(0, 255, 0);
  } else {
    fill(255);
  }
  text("vX: " + String.format("%.3f", vX), posX, posY-20);
}

void drawText() {
  long time = (starttime == 0 ? 0 : (state == State.END ? totaltime : millis()-starttime));
  String tst = "Time: " + String.format("%.3f", (time/1000.0));
  fill(0);
  textAlign(RIGHT);
  text(tst, 790, 25);
  text(best, 790, 50);
}

void getBest() {
  Properties prop = new Properties();
  InputStream input = null;
  try {
    input = new FileInputStream(sketchPath() + "/stats.properties");
    prop.load(input);
    if (prop.containsKey("Level" + (level+1))) {
      best = "Best: " + (Long.parseLong(prop.getProperty("Level" + (level+1)))/1000.0);
    } else {
      best = "Best: No best time";
    }
  } 
  catch (IOException ex) {
    ex.printStackTrace();
  } 
  finally {
    if (input != null) {
      try {
        input.close();
      } 
      catch (IOException e) {
        e.printStackTrace();
      }
    }
  }
}

void getSerial() {
  if (myPort != null) {
    while ( myPort.available() > 0) {
      String result = myPort.readStringUntil('\n');
      if (result != null) {
        if (result.startsWith("X")) {
          forceX = Float.parseFloat(result.replace("X", "").replace("\n", ""))*1;
        }
        if (result.startsWith("Y")) {
          if (result.contains("true")) {
            if (state == State.END && waittillnext <= millis()) {
              reset(win);
            } else {
              forceY = true;
            }
          } else {
            forceY = false;
          }
          v0Y = vY;
          timeY = 0;
        }
      }
    }
  }
}

void physics() {
  timeY += delay;
  vY = (forceY ? v0Y + ((double)(aY+fY)*((double)timeY/1000.0)) : v0Y + aY*((double)timeY/1000.0));
  if (forceX > 1 || forceX < -1) {
    vX += (forceX/20.0);
  }
  posY += vY;
  posX += vX;
}

boolean collide(float minX, float maxX, float minY, float maxY) {
  for (int x = (int)minX; x < maxX; x ++) {
    for (int y = (int)minY; y < maxY; y ++) {
      color c = levelBlanks[level].get(x, y);
      float r = red(c);
      float g = green(c);
      float b = blue(c);
      if (r > 250 && g > 250 && b > 250) {
        return true;
      }
    }
  }
  return false;
}

void testPlatform() {
  for (int x = (int)posX+15; x < posX+25; x ++) {
    color c = levelBlanks[level].get(x, (int)posY+25);
    float r = red(c);
    float g = green(c);
    float b = blue(c);
    if (r >= 250 && g <= 5 && b <= 5) {
      for (x = (int)posX-25; x < posX-15; x ++) {
        c = levelBlanks[level].get(x, (int)posY+25);
        r = red(c);
        g = green(c);
        b = blue(c);
        if (r >= 250 && g <= 5 && b <= 5) {
          fill(255);
          if (vY <= 0.7 && vX <= 0.7 && vX >= -0.7) {
            win = true;
            Firework fw = new Firework(posX, posY);
            fireworks.add(fw);
          } else {
            crash = true;
          }
          break;
        }
      }
      if (!win) {
        crash = true;
      }
      break;
    }
  }
  if (!win) {
    for (int x = (int)posX-25; x < posX-15; x ++) {
      color c = levelBlanks[level].get(x, (int)posY+25);
      float r = red(c);
      float g = green(c);
      float b = blue(c);
      if (r >= 250 && g <= 5 && b <= 5) {
        crash = true;
        break;
      }
    }
  }
}

void makeParticles() {
  if (forceY) {
    for (int i = 0; i < 40; i ++) {
      color c = levelBlanks[level].get((int)posX, (int)posY+15+i);
      float r = red(c);
      if (r > 250) {
        for (double angle = -60; angle <= 60; angle+=(random(1.1)+0.3*(Math.abs(angle)/10.0))) {
          Particle p = new Particle((int)posX, (int)posY+15+i, angle, random(1.4)+0.3, levelMaps[level].get((int)posX, (int)posY+15+i), false);
          particles.add(p);
        }
        break;
      }
    }
  }
}

void evaluateParticles() {
  for (Particle p : particles) {
    p.evaluate();
  }
}

void drawFlames() {
  if (forceY) {
    fireAnimation ++;
    fireAnimation = fireAnimation % 3;
    image(fire[fireAnimation], posX-fire[fireAnimation].width/2, posY+15);
  }
  if (forceX < -1) {
    fireAnimation_right ++;
    fireAnimation_right = fireAnimation_right % 3;
    pushMatrix();
    translate(posX+fire[fireAnimation_right].width-15, posY+20);
    rotate(-90*PI/180);
    image(fire[fireAnimation_right], 0, 0, 20, 20);
    popMatrix();
  }
  if (forceX > 1) {
    fireAnimation_left ++;
    fireAnimation_left = fireAnimation_left % 3;
    pushMatrix();
    translate(posX-fire[fireAnimation_left].width+15, posY);
    rotate(90*PI/180);
    image(fire[fireAnimation_left], 0, 0, 20, 20);
    popMatrix();
  }
}

void drawParticles() {
  ArrayList<Explosion> remove = new ArrayList<Explosion>();
  for (Explosion ex : explosions) {
    if (ex.isAlive()) {
      ex.drawImg();
    } else {
      remove.add(ex);
    }
  }
  for (Explosion ex : remove) {
    explosions.remove(ex);
  }
  ArrayList<Particle> removeParticle = new ArrayList<Particle>();
  for (Particle p : particles) {
    if (p.isAlive()) {
      p.drawp();
    } else {
      removeParticle.add(p);
    }
  }
  for (Particle p : removeParticle) {
    particles.remove(p);
  }
  ArrayList<Firework> removeFirework = new ArrayList<Firework>();
  for (Firework fw : fireworks) {
    if (fw.isAlive()) {
      fw.step();
    } else {
      removeFirework.add(fw);
    }
  }
  for (Firework fw : removeFirework) {
    fireworks.remove(fw);
  }
}

void keyPressed() {
  if (key == 'w') {
    if (!forceY) {
      if (state == State.END && waittillnext <= millis()) {
        reset(win);
      } else {
        forceY = true;
        v0Y = vY;
        timeY = 0;
      }
    }
  }
  if (key == 'a') {
    if (!apressed) {
      apressed = true;
      forceX += 2;
    }
  }
  if (key == 'd') {
    if (!dpressed) {
      dpressed = true;
      forceX -= 2;
    }
  }
}

void reset(boolean won) {
  v0Y = 0.0;
  vY = 0.0;
  vX = 0.0;

  timeY = 0;
  starttime = 0;

  state = State.CALIBRY;
  win = false;
  crash = false;

  forceY = false;
  apressed = false;
  dpressed = false;
  forceX = -16;

  posX = 400;
  posY = 100;

  crashAnimation = 0;
  winAnimation = 0;
  fireAnimation = 0;
  fireAnimation_left = 0;
  fireAnimation_right = 0;

  best = "Best: reset";
  totaltime = 0;
  particles.clear();
  explosions.clear();
  if (won) {
    level ++;
    level = level % 4;
  }
  image(levelMaps[level], 0, 0);
}

void keyReleased() {
  if (key == 'w') {
    if (forceY) {
      forceY = false;
      v0Y = vY;
      timeY = 0;
    }
  }
  if (key == 'a') {
    if (apressed) {
      apressed = false;
    }
  }
  if (key == 'd') {
    if (dpressed) {
      dpressed = false;
    }
  }
}

class Explosion {

  int x;
  int y;
  int state;
  boolean alive;

  public int getX() {
    return x;
  }

  public boolean isAlive() {
    return alive;
  }

  public Explosion(int x, int y) {
    this.x = x;
    this.y = y;
    state = 0;
    alive = true;
  }

  void drawImg() {
    if (alive) {
      PImage img = explosion.get((state%4)*128, (state/4)*128, 128, 128);
      img.resize(50, 50);
      tint(random(56)+200);
      image(img, x-25, y-25);
      state ++;
      if (state == 16) {
        alive = false;
      }
      tint(255);
    }
  }
}

class Particle {

  float posX;
  float posY;
  double vX;
  double vY;
  double v0Y;
  int timeY = 0;
  color c;
  boolean alive = true;
  boolean fade;
  int[] fadex = new int[10];
  int[] fadey = new int[10];
  int fadepos = 0;

  public boolean isAlive() {
    return alive;
  }

  public Particle(int x, int y, double angle, float force, color c, boolean fade) {
    posX = x;
    posY = y-2;
    this.fade = fade;
    this.c = c;
    if (angle < 0) {
      vX = -(cos((float)((90+angle)*PI/180.0)))*force;
      vY = -(sin((float)((90+angle)*PI/180.0)))*force;
      v0Y = vY;
    } else {
      vX = (cos((float)((90-angle)*PI/180.0)))*force;
      vY = -(sin((float)((90-angle)*PI/180.0)))*force;
      v0Y = vY;
    }
  }

  public void evaluate() {
    timeY += delay;
    vY = v0Y + aY*((double)timeY/1000.0);
    posX += vX;
    posY += vY;
    color col = levelBlanks[level].get((int)posX, (int)posY);
    float r = red(col);
    float g = green(col);
    float b = blue(col);
    if (r > 250 && g > 250 && b > 250) {
      alive = false;
    }
    if (timeY >= 3500-2550) {
      tint((4000-timeY)/10);
    }
    tint(255);
    if (timeY >= 3500) {
      alive = false;
    }
    if (fade) {
      fadex[fadepos] = (int)posX;
      fadey[fadepos] = (int)posY;
      fadepos ++;
      fadepos = fadepos%10;
    }
  }

  public void drawp() {
    fill(c);
    noStroke();
    rect(posX, posY, 1, 1);
    if (fade) {
      for (int i = 0; i < 10; i ++) {
        if (!(fadex[i] == 0 && fadey[i] == 0)) {
          rect(fadex[i], fadey[i], 1, 1);
        }
      }
    }
  }
}

class Firework
{
  float x;
  float y;
  double a = 2.5;
  double v = 0;
  float time;
  float explosion;
  PImage fw;
  boolean alive = true;

  public boolean isAlive() {
    return alive;
  }

  public Firework(float x, float y) {
    this.x = x;
    this.y = y;
    fw = loadImage("fireworks.png");
    fw.resize(30, 30);
  }

  public void step() {
    time += delay;
    if (time < 3000) {
      v = a*((double)time/1000.0);
      x += random(-1.9, 1.9);
      y -= v;
      image(fw, x, y);
    } else {
      alive = false;
      for (double angle = -180; angle <= 180; angle+=2) {
        Particle p = new Particle((int)x, (int)y, angle, random(0.3)+3.0, color(255, 0, 0), true);
        particles.add(p);
      }
    }
  }
}