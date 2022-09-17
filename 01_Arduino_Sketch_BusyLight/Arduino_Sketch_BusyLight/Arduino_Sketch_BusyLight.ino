/*********************************************************************
 Adafruit invests time and resources providing this open source code,
 please support Adafruit and open-source hardware by purchasing
 products from Adafruit!

 MIT license, check LICENSE for more information
 Copyright (c) 2019 Ha Thach for Adafruit Industries
 All text above, and the splash screen below must be included in
 any redistribution
*********************************************************************/

#include "SPI.h"
#include "SdFat.h"
#include "Adafruit_InternalFlash.h"
#include "Adafruit_TinyUSB.h"

#include <Adafruit_NeoPixel.h>
#include "Adafruit_FreeTouch.h"

// Start address and size should matches value in the CircuitPython (INTERNAL_FLASH_FILESYSTEM = 1)
// to make it easier to switch between Arduino and CircuitPython
#define INTERNAL_FLASH_FILESYSTEM_START_ADDR  (0x00040000 - 256 - 0 - INTERNAL_FLASH_FILESYSTEM_SIZE)
#define INTERNAL_FLASH_FILESYSTEM_SIZE        (128*1024)

// Internal Flash object
Adafruit_InternalFlash flash(INTERNAL_FLASH_FILESYSTEM_START_ADDR, INTERNAL_FLASH_FILESYSTEM_SIZE);

// file system object from SdFat
FatFileSystem fatfs;

FatFile root;
FatFile file;

// USB MSC object
Adafruit_USBD_MSC usb_msc;

// Set to true when PC write to flash
bool fs_changed;

// Create the neopixel strip with the built in definitions NUM_NEOPIXEL and PIN_NEOPIXEL
Adafruit_NeoPixel strip = Adafruit_NeoPixel(NUM_NEOPIXEL, PIN_NEOPIXEL, NEO_GRB + NEO_KHZ800);

// Create the two touch pads on pins 1 and 2:
Adafruit_FreeTouch qt_1 = Adafruit_FreeTouch(1, OVERSAMPLE_4, RESISTOR_50K, FREQ_MODE_NONE);
Adafruit_FreeTouch qt_2 = Adafruit_FreeTouch(2, OVERSAMPLE_4, RESISTOR_50K, FREQ_MODE_NONE);

// the setup function runs once when you press reset or power the board
void setup()
{
  // Initialize internal flash
  flash.begin();

  // Set disk vendor id, product id and revision with string up to 8, 16, 4 characters respectively
  usb_msc.setID("Adafruit", "Internal Flash", "1.0");

  // Set callback
  usb_msc.setReadWriteCallback(msc_read_callback, msc_write_callback, msc_flush_callback);
  usb_msc.setWritableCallback(msc_writable_callback);

  // Set disk size, block size should be 512 regardless of flash page size
  usb_msc.setCapacity(flash.size()/512, 512);

  // Set Lun ready
  usb_msc.setUnitReady(true);

  usb_msc.begin();

  // Init file system on the flash
  fatfs.begin(&flash);

  Serial.begin(9600);
  // Set to 10ms otherwise the receive function will wait for 1s before returning data
  Serial.setTimeout(10);

  fs_changed = true; // to print contents initially
  
  strip.begin();
  strip.setBrightness(255);
  strip.show(); // Initialize all pixels to 'off'

  for(int i = 0; i < 4 ; i++)
  {
    Spin(strip.Color(100,0,0));
    delay(100);
  }
  
  for(int i = 0; i < 4 ; i++)
  {
    Spin(strip.Color(0,100,0));
    delay(100);
  }
  
  for(int i = 0; i < 4 ; i++)
  {
    Spin(strip.Color(0,0,100));
    delay(100);
  }
  
  strip.setPixelColor(0, 0);
  strip.setPixelColor(1, 0);
  strip.setPixelColor(2, 0);
  strip.setPixelColor(3, 0);
  strip.show();
}

void loop()
{
  if (Serial.available() > 0) 
  {
    String data_str = Serial.readStringUntil(',');
    // But since we want it as an integer we parse it.
    int brightness_red = data_str.toInt();
    
    data_str = Serial.readStringUntil(',');
    // But since we want it as an integer we parse it.
    int brightness_green = data_str.toInt();
    
    data_str = Serial.readStringUntil('\r');
    // But since we want it as an integer we parse it.
    int brightness_blue = data_str.toInt();
    
    strip.setPixelColor(0, strip.Color(brightness_red, brightness_green, brightness_blue));
    strip.setPixelColor(1, strip.Color(brightness_red, brightness_green, brightness_blue));
    strip.setPixelColor(2, strip.Color(brightness_red, brightness_green, brightness_blue));
    strip.setPixelColor(3, strip.Color(brightness_red, brightness_green, brightness_blue));
    strip.show();

    delay(10);
  }
}

// Callback invoked when received READ10 command.
// Copy disk's data to buffer (up to bufsize) and
// return number of copied bytes (must be multiple of block size)
int32_t msc_read_callback (uint32_t lba, void* buffer, uint32_t bufsize)
{
  // Note: InternalFlash Block API: readBlocks/writeBlocks/syncBlocks
  // already include sector caching (if needed). We don't need to cache it, yahhhh!!
  return flash.readBlocks(lba, (uint8_t*) buffer, bufsize/512) ? bufsize : -1;
}

// Callback invoked when received WRITE10 command.
// Process data in buffer to disk's storage and
// return number of written bytes (must be multiple of block size)
int32_t msc_write_callback (uint32_t lba, uint8_t* buffer, uint32_t bufsize)
{
  // Note: InternalFlash Block API: readBlocks/writeBlocks/syncBlocks
  // already include sector caching (if needed). We don't need to cache it, yahhhh!!
  return flash.writeBlocks(lba, buffer, bufsize/512) ? bufsize : -1;
}

// Callback invoked when WRITE10 command is completed (status received and accepted by host).
// used to flush any pending cache.
void msc_flush_callback (void)
{
  // sync with flash
  flash.syncBlocks();

  // clear file system's cache to force refresh
  fatfs.cacheClear();

  fs_changed = true;
}

// Invoked to check if device is writable as part of SCSI WRITE10
// Default mode is writable
bool msc_writable_callback(void)
{
  // true for writable, false for read-only
  return true;
}

void Spin(uint32_t color) 
{
  static int position = 0;
  switch (position)
  {
    case 0:
      strip.setPixelColor(0, color);
      strip.setPixelColor(1, 0);
      strip.setPixelColor(2, 0);
      strip.setPixelColor(3, 0);
      break;
    case 1:
      strip.setPixelColor(0, 0);
      strip.setPixelColor(1, color);
      strip.setPixelColor(2, 0);
      strip.setPixelColor(3, 0);
      break;
    case 2:
      strip.setPixelColor(0, 0);
      strip.setPixelColor(1, 0);
      strip.setPixelColor(2, color);
      strip.setPixelColor(3, 0);
      break;
    case 3:
      strip.setPixelColor(0, 0);
      strip.setPixelColor(1, 0);
      strip.setPixelColor(2, 0);
      strip.setPixelColor(3, color);
      break;
    default:
      strip.setPixelColor(0, 0);
      strip.setPixelColor(1, 0);
      strip.setPixelColor(2, 0);
      strip.setPixelColor(3, 0);
      break;
  }

  position++;
  position %= 4;
  strip.show();
}
