package com.visioncameratextrecognition;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.media.Image;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.WritableNativeMap;
import com.mrousavy.camera.frameprocessors.Frame;
import com.mrousavy.camera.frameprocessors.FrameProcessorPlugin;
import com.mrousavy.camera.frameprocessors.VisionCameraProxy;

import java.util.Map;

import com.visioncameratextrecognition.utils.YuvToRgbConverter;

public class VisionCameraHeartRatePlugin extends FrameProcessorPlugin {

  private YuvToRgbConverter yuvToRgbConverter;
  private final BandPassFilter hueFilter = new BandPassFilter();
  private final PulseDetector pulseDetector = new PulseDetector();

  private int BPM = 0;
  private String state = "RECORDING";
  private int validFrameCounter = 0;

  public VisionCameraHeartRatePlugin(VisionCameraProxy visionCameraProxy, Map<String, Object> stringObjectMap) {
		super();
		yuvToRgbConverter = new YuvToRgbConverter(visionCameraProxy.getContext());
	}

  private int calculateAverageColor(Bitmap bitmap) {
    int R = 0;
    int G = 0;
    int B = 0;
    int height = bitmap.getHeight();
    int width = bitmap.getWidth();
    int n = 0;
    int[] pixels = new int[width * height];
    bitmap.getPixels(pixels, 0, width, 0, 0, width, height);
    for (int i = 0; i < pixels.length; i += 1) {
      int color = pixels[i];
      R += Color.red(color);
      G += Color.green(color);
      B += Color.blue(color);
      n++;
    }
    return Color.rgb(R / n, G / n, B / n);
  }

  private void reset() {
    pulseDetector.reset();
    validFrameCounter = 0;
    state = "BEGIN";
    BPM = 0;
  }

	@Nullable
	@Override
	public Object callback(@NonNull Frame frame, @Nullable Map<String, Object> params) throws Throwable {
		Image image = frame.getImage();
		if (image == null) {
			return null;
		}

		// if (params.length > 0 && params.get('shouldReset') instanceof String) {
		// 	if (((String) params['shouldReset']).equals("true")) {
		// 		reset();
		// 	}
		// }

		Bitmap bitmap = Bitmap.createBitmap(
			image.getWidth(),
			image.getHeight(),
			Bitmap.Config.ARGB_8888
		);
		yuvToRgbConverter.yuvToRgb(image, bitmap);

		int higher = Math.max(bitmap.getWidth(), bitmap.getHeight());
		int lower = Math.min(bitmap.getWidth(), bitmap.getHeight());
		int resizedHeight = 100;
		int resizedWidth = (int) (((float) lower / (float) higher) * resizedHeight);
		Bitmap resized = Bitmap.createScaledBitmap(
			bitmap,
			resizedWidth,
			resizedHeight,
			false
		);
		int average = calculateAverageColor(resized);

		float[] hsv = new float[3];
		Color.colorToHSV(
			Color.rgb(Color.red(average), Color.green(average), Color.blue(average)),
			hsv
		);
		float hue = hsv[0];
		float saturation = hsv[1];
		float brightness = hsv[2];
		double filtered = 0.0;
		if (saturation > 0.5 && brightness > 0.5) {
			state = "RECORDING";
			BPM = (int) (60.0f / pulseDetector.getAverage());
			validFrameCounter += 1;

			// Filter the hue value - the filter is a simple BAND PASS FILTER that removes
			// any DC component and any high frequency noise
			if (validFrameCounter > 60) {
				filtered = hueFilter.processValue((double) (hue));
				float upOrDown = pulseDetector.addNewValue(
					filtered,
					System.currentTimeMillis() / (double) (1000.0)
				);
			}
		} else {
			reset();
		}

		WritableNativeMap result = new WritableNativeMap();
		result.putDouble("hue", hue);
		result.putDouble("saturation", saturation);
		result.putDouble("brightness", brightness);
		result.putDouble("filtered", filtered);
		result.putInt("red", Color.red(average));
		result.putDouble("BPM", BPM);
		result.putString("state", state);
		result.putDouble("count", validFrameCounter);
		result.putDouble("time", System.currentTimeMillis() / (double) (1000.0));
		return result.toString();
	}
}
