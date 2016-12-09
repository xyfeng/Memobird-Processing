import java.io.*;
import java.util.Date;
import java.util.Base64;
import javax.imageio.ImageIO;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.text.SimpleDateFormat;
import http.requests.*;

// Maximum Image Print Width 384px

// Configuration
String MEMOBIRD_AK = "YOUR_ACCESS_KEY";
String MEMOBIRD_ID = "YOUR_DEVICE_ID";
String MEMOBIRD_USER = "YOUR_ACCOUNT_USERNAME";
String MEMOBIRD_API_USER_ID;

void setup() {
  // bind it first
  bindDevice();

  PImage image = loadImage("cat.jpeg");

  // command to print
  postToPrint(image, "Hello World!");
}

String getTimestamp() {
  // 2016-12-06%12:21:54
  Date date = new Date();
  SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd%HH:mm:ss");
  return formatter.format(date);
}

// API Bind Device Sample Code
// http://open.memobird.cn/home/setuserbind?
// ak=c7548afbab99479e9f9a59aa1d65d5c6&
// timestamp=2014-11-14%2014:22:39&
// memobirdID=138ca2ba62125fb6&
// useridentifying=12121233
void bindDevice() {
  String requestURL = "http://open.memobird.cn/home/setuserbind";
  PostRequest post = new PostRequest(requestURL);

  post.addData("ak", MEMOBIRD_AK);
  post.addData("timestamp", getTimestamp());
  post.addData("memobirdID", MEMOBIRD_ID);
  post.addData("useridentifying", MEMOBIRD_USER);

  post.send();

  //println("BIND SUCCESSFULLY ", post.getContent());
  JSONObject result = parseJSONObject(post.getContent());
  if (result != null) {
    MEMOBIRD_API_USER_ID = str(result.getInt("showapi_userid"));
    println("BIND SUCCESSFULLY ", MEMOBIRD_API_USER_ID);
  }
}

String encodeString(String str) {
  return Base64.getEncoder().encodeToString(str.getBytes());
}

String encodeImage(PImage img) {
  img.resize(384, 0);
  img.filter(GRAY);
  BufferedImage ditheredImg = ditherImage(img);

  try {
    ImageIO.write(ditheredImg, "bmp", new File(sketchPath("")  + "data/temp.bmp"));
  }
  catch (Exception e)
  {
    e.printStackTrace();
  }

  byte[] bytes = loadBytes("temp.bmp");
  return Base64.getEncoder().encodeToString(bytes);
}

// API Print Content Sample Code
// http://open.memobird.cn/home/printpaper?
// ak=c7548afbab99479e9f9a59aa1d65d5c6&
// timestamp=2014-11-14%2014:22:39&
// memobirdID=138ca2ba62125fb6&
// userid=12121233&
// printcontent=T:d2VsY29tZSB0byB5b3U=|P:Qk0OAgAAAAAAAD4AAAAoAAAAOgAAAMb///8BAAEAAAAAAAAAAADEDgAAxA4AAAIAAAACAAAAAAAA//////8A///////AAAP///////AAB///////+AAf///////+AB////////4AP///++/f/wB////719//gH////frv/+A////+7ff/8D////779//wP/////37//A////9dW//8D////6rV//wP////a1r//A////+1bf/8D////7/7//wP/////////A/////qr//8D////7/1//wP////aq7//A////3/+1/8D////1VX//wP///17v1f/A////67q+v8D///1d3ev/wP////a3XX/A///9X/73v8D///+1R7rfwP//7XvG17/A//+21u9978D//1v/vda/wP/+6qr2+9/A//1bfbtW78D/263Xb/2/wP/9arvaq2/A/3vV7Xff38D//f63vXV/wP23/93Xvt/A///f9vrV78D/33/dr39fwP19+/d11f/A//f/+77uv8D//9/t1bv/wP/e//b/bX/A//v//1Xf/8D//7/q7vX/wP////e7X//A//7/3W3v/8D////333//wP///9r1v//Af///717//4B///+76///gD///+1///8AH////////gAf///////+AAf///////gAA///////8AAA///////AAA==

void postToPrint(PImage img, String str) {
  String content = "";
  if ( str != null ) {
    content += "T:" + encodeString(str);
  }
  if ( img != null ) {
    content += "|P:" + encodeImage(img);
  }

  //println(content);

  String requestURL = "http://open.memobird.cn/home/printpaper";
  PostRequest post = new PostRequest(requestURL);

  post.addData("ak", MEMOBIRD_AK);
  post.addData("timestamp", getTimestamp());
  post.addData("memobirdID", MEMOBIRD_ID);
  post.addData("userid", MEMOBIRD_API_USER_ID);
  post.addData("printcontent", content);

  post.send();

  println("Print Reponse: " + post.getContent());
}


/**
 * Performs Floyd-Steinberg dithering according to
 * http://en.wikipedia.org/wiki/Floyd%E2%80%93Steinberg_dithering
 */
BufferedImage ditherImage(PImage img) {
  BufferedImage bi = new BufferedImage(img.width, img.height, BufferedImage.TYPE_INT_RGB);
  bi.getGraphics().drawImage(img.getImage(), 0, 0, null);

  int width = bi.getWidth();
  int height = bi.getHeight();

  int red[][] = new int[width][height];
  int grn[][] = new int[width][height];
  int blu[][] = new int[width][height];


  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      red[x][y] = bi.getRGB(x, y) >> 16 & 0xFF; // unsigned int
      grn[x][y] = bi.getRGB(x, y) >> 8 & 0xFF;  // unsigned int
      blu[x][y] = bi.getRGB(x, y) & 0xFF;       // unsigned int
    }
  }
  int[][] pixel_floyd = dither(red, height, width);
  BufferedImage ditheredImage = new BufferedImage(width, height, BufferedImage.TYPE_BYTE_BINARY);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      int pixel = ((int) pixel_floyd[x][y] << 16)
        | ((int) pixel_floyd[x][y] << 8)
        | ((int) pixel_floyd[x][y]);
      ditheredImage.setRGB(x, y, pixel);
    }
  }
  return ditheredImage;
}

int[][] dither(int[][] pixel, int height, int width) {
  int oldpixel, newpixel, error;
  boolean nbottom, nleft, nright;

  for (int y = 0; y < height; y++) {
    nbottom = y < height - 1;

    for (int x = 0; x < width; x++) {
      nleft = x > 0;
      nright = x < width - 1;

      oldpixel = pixel[x][y];
      newpixel = oldpixel < 128 ? 0 : 255;

      pixel[x][y] = newpixel;

      error = oldpixel - newpixel;

      if (nright) {
        pixel[x + 1][y] += 7 * error / 16;
      }
      if (nleft & nbottom) {
        pixel[x - 1][y + 1] += 3 * error / 16;
      }
      if (nbottom) {
        pixel[x][y + 1] += 5 * error / 16;
      }
      if (nright && nbottom) {
        pixel[x + 1][y + 1] += error / 16;
      }
    }
  }
  return pixel;
}
