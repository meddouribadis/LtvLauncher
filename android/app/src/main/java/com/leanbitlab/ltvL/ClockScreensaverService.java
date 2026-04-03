package com.omeda.arc;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.AnimatorSet;
import android.animation.ObjectAnimator;
import android.animation.PropertyValuesHolder;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.service.dreams.DreamService;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import android.widget.FrameLayout;
import android.widget.TextView;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Random;

public class ClockScreensaverService extends DreamService {
    private FrameLayout container;
    private Handler handler;
    private Runnable updateTimeRunnable;
    private Runnable moveClockRunnable;
    private Random random;
    private int screenWidth;
    private int screenHeight;

    private List<TextView> timeCharViews = new ArrayList<>();
    private List<TextView> dateCharViews = new ArrayList<>();
    private List<TextView> amPmCharViews = new ArrayList<>();

    private float currentCenterX;
    private float currentCenterY;
    private float targetCenterX;
    private float targetCenterY;

    private static final int TIME_FONT_SIZE = 80; // sp
    private static final int DATE_FONT_SIZE = 32; // sp
    private static final int AMPM_FONT_SIZE = 32; // sp (~40% of TIME_FONT_SIZE)
    private static final int CHAR_ANIMATION_DURATION = 800; // ms per character
    private static final int CHAR_STAGGER_DELAY = 100; // ms between characters

    @Override
    public void onAttachedToWindow() {
        super.onAttachedToWindow();

        setInteractive(false);
        setFullscreen(true);

        // Create container
        container = new FrameLayout(this);
        container.setBackgroundColor(Color.BLACK);
        setContentView(container);

        handler = new Handler(Looper.getMainLooper());
        random = new Random();

        // Get screen dimensions
        DisplayMetrics metrics = getResources().getDisplayMetrics();
        screenWidth = metrics.widthPixels;
        screenHeight = metrics.heightPixels;

        // Initial position at center
        currentCenterX = screenWidth / 2f;
        currentCenterY = screenHeight / 2f;
        targetCenterX = currentCenterX;
        targetCenterY = currentCenterY;

        // Update time every minute
        updateTimeRunnable = () -> {
            updateTime();
            handler.postDelayed(updateTimeRunnable, 60000);
        };

        // Move clock every 30 seconds
        moveClockRunnable = () -> {
            animateToNewPosition();
            handler.postDelayed(moveClockRunnable, 30000);
        };

        // Initial setup
        createCharacterViews();
        updateTime();

        // Start handlers with initial delay
        handler.postDelayed(moveClockRunnable, 30000);
        handler.post(updateTimeRunnable);
    }

    private void createCharacterViews() {
        // Get current time and date strings
        SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        String timeFormatString = prefs.getString("flutter.time_format", "H:mm");
        String dateFormatString = prefs.getString("flutter.date_format", "EEEE d");

        SimpleDateFormat timeFormat = new SimpleDateFormat(timeFormatString, Locale.getDefault());
        SimpleDateFormat dateFormat = new SimpleDateFormat(dateFormatString, Locale.getDefault());

        String timeStr = timeFormat.format(new Date());
        String dateStr = dateFormat.format(new Date());

        // Clear existing views
        container.removeAllViews();
        timeCharViews.clear();
        dateCharViews.clear();
        amPmCharViews.clear();

        // Detect AM/PM in time string
        String amPmSuffix = "";
        String timeDigits = timeStr;
        if (timeStr.toUpperCase().endsWith("AM") || timeStr.toUpperCase().endsWith("PM")) {
            amPmSuffix = timeStr.substring(timeStr.length() - 2);
            timeDigits = timeStr.substring(0, timeStr.length() - 2).trim();
        }

        // Create time character views (digits at full size)
        float timeWidth = 0;
        for (int i = 0; i < timeDigits.length(); i++) {
            TextView charView = createCharView(String.valueOf(timeDigits.charAt(i)), TIME_FONT_SIZE);
            timeCharViews.add(charView);
            container.addView(charView);
            timeWidth += getCharWidth(charView);
        }

        // Create AM/PM characters at smaller size (tracked separately for
        // bottom-alignment)
        if (!amPmSuffix.isEmpty()) {
            // Add a small space (counted in time width for centering)
            TextView spaceView = createCharView(" ", AMPM_FONT_SIZE);
            amPmCharViews.add(spaceView);
            container.addView(spaceView);
            timeWidth += getCharWidth(spaceView);

            for (int i = 0; i < amPmSuffix.length(); i++) {
                TextView charView = createCharView(String.valueOf(amPmSuffix.charAt(i)), AMPM_FONT_SIZE);
                amPmCharViews.add(charView);
                container.addView(charView);
                timeWidth += getCharWidth(charView);
            }
        }

        // Create date character views
        float dateWidth = 0;
        for (int i = 0; i < dateStr.length(); i++) {
            TextView charView = createCharView(String.valueOf(dateStr.charAt(i)), DATE_FONT_SIZE);
            dateCharViews.add(charView);
            container.addView(charView);
            dateWidth += getCharWidth(charView);
        }

        // Position characters at center
        positionCharacters(currentCenterX, currentCenterY, false);
    }

    private TextView createCharView(String character, int fontSize) {
        SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        String clockStyle = prefs.getString("flutter.screensaver_clock_style", "minimal");

        TextView tv = new TextView(this);
        tv.setText(character);
        tv.setTextColor(Color.WHITE);
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSize);

        switch (clockStyle) {
            case "bold":
                tv.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
                break;
            case "retro":
                tv.setTypeface(Typeface.create("monospace", Typeface.NORMAL));
                break;
            case "elegant":
                tv.setTypeface(Typeface.create("serif", Typeface.NORMAL));
                break;
            case "neon":
                tv.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
                break;
            case "pixel":
                tv.setTypeface(Typeface.create("monospace", Typeface.BOLD));
                break;
            case "digital":
                tv.setTypeface(Typeface.create("monospace", Typeface.NORMAL));
                break;
            default: // "minimal"
                tv.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
                break;
        }

        tv.setGravity(Gravity.CENTER);
        tv.setShadowLayer(15, 0, 0, 0x60FFFFFF);
        tv.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT));
        return tv;
    }

    private float getCharWidth(TextView tv) {
        tv.measure(0, 0);
        return tv.getMeasuredWidth();
    }

    private float getCharHeight(TextView tv) {
        tv.measure(0, 0);
        return tv.getMeasuredHeight();
    }

    private void positionCharacters(float centerX, float centerY, boolean animate) {
        // Calculate total widths
        float timeWidth = 0;
        for (TextView tv : timeCharViews) {
            timeWidth += getCharWidth(tv);
        }

        float dateWidth = 0;
        for (TextView tv : dateCharViews) {
            dateWidth += getCharWidth(tv);
        }

        float timeHeight = timeCharViews.isEmpty() ? 0 : getCharHeight(timeCharViews.get(0));
        float dateHeight = dateCharViews.isEmpty() ? 0 : getCharHeight(dateCharViews.get(0));
        float totalHeight = timeHeight + dateHeight + 20; // 20px gap

        // Calculate total width including AM/PM for centering
        float totalTimeWidth = timeWidth;
        for (TextView tv : amPmCharViews) {
            totalTimeWidth += getCharWidth(tv);
        }

        // Position time characters (digits only)
        float timeStartX = centerX - totalTimeWidth / 2;
        float timeY = centerY - totalHeight / 2;
        float currentX = timeStartX;

        for (TextView tv : timeCharViews) {
            float charWidth = getCharWidth(tv);
            if (animate) {
                tv.setTag(new float[] { currentX, timeY });
            } else {
                tv.setX(currentX);
                tv.setY(timeY);
            }
            currentX += charWidth;
        }

        // Position AM/PM characters at the BOTTOM of the time row
        float amPmHeight = amPmCharViews.isEmpty() ? 0 : getCharHeight(amPmCharViews.get(0));
        float amPmY = timeY + timeHeight - amPmHeight;
        for (TextView tv : amPmCharViews) {
            float charWidth = getCharWidth(tv);
            if (animate) {
                tv.setTag(new float[] { currentX, amPmY });
            } else {
                tv.setX(currentX);
                tv.setY(amPmY);
            }
            currentX += charWidth;
        }

        // Position date characters
        float dateStartX = centerX - dateWidth / 2;
        float dateY = centerY - totalHeight / 2 + timeHeight + 20;
        currentX = dateStartX;

        for (TextView tv : dateCharViews) {
            float charWidth = getCharWidth(tv);
            if (animate) {
                tv.setTag(new float[] { currentX, dateY });
            } else {
                tv.setX(currentX);
                tv.setY(dateY);
            }
            currentX += charWidth;
        }
    }

    private void updateTime() {
        SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        String timeFormatString = prefs.getString("flutter.time_format", "H:mm");
        String dateFormatString = prefs.getString("flutter.date_format", "EEEE d");

        SimpleDateFormat timeFormat = new SimpleDateFormat(timeFormatString, Locale.getDefault());
        SimpleDateFormat dateFormat = new SimpleDateFormat(dateFormatString, Locale.getDefault());

        String timeStr = timeFormat.format(new Date());
        String dateStr = dateFormat.format(new Date());

        // Detect AM/PM in time string
        String amPmSuffix = "";
        String timeDigits = timeStr;
        if (timeStr.toUpperCase().endsWith("AM") || timeStr.toUpperCase().endsWith("PM")) {
            amPmSuffix = timeStr.substring(timeStr.length() - 2);
            timeDigits = timeStr.substring(0, timeStr.length() - 2).trim();
        }

        // Update time digit characters
        for (int i = 0; i < timeCharViews.size() && i < timeDigits.length(); i++) {
            timeCharViews.get(i).setText(String.valueOf(timeDigits.charAt(i)));
        }

        // Update AM/PM characters (index 0=space, 1=A/P, 2=M)
        if (!amPmSuffix.isEmpty() && amPmCharViews.size() >= 3) {
            amPmCharViews.get(1).setText(String.valueOf(amPmSuffix.charAt(0)));
            amPmCharViews.get(2).setText(String.valueOf(amPmSuffix.charAt(1)));
        }

        // Check if we need to recreate views (text length changed)
        int expectedAmPmCount = amPmSuffix.isEmpty() ? 0 : 3; // space + 2 chars
        if (timeDigits.length() != timeCharViews.size()
                || expectedAmPmCount != amPmCharViews.size()
                || dateStr.length() != dateCharViews.size()) {
            createCharacterViews();
        } else {
            // Update date characters
            for (int i = 0; i < dateCharViews.size() && i < dateStr.length(); i++) {
                dateCharViews.get(i).setText(String.valueOf(dateStr.charAt(i)));
            }
        }
    }

    private void animateToNewPosition() {
        // Calculate new random position
        float margin = 150;
        float maxWidth = 0;
        for (TextView tv : timeCharViews) {
            maxWidth += getCharWidth(tv);
        }
        for (TextView tv : amPmCharViews) {
            maxWidth += getCharWidth(tv);
        }
        float totalHeight = (timeCharViews.isEmpty() ? 0 : getCharHeight(timeCharViews.get(0))) +
                (dateCharViews.isEmpty() ? 0 : getCharHeight(dateCharViews.get(0))) + 20;

        float maxX = screenWidth - maxWidth / 2 - margin;
        float minX = maxWidth / 2 + margin;
        float maxY = screenHeight - totalHeight / 2 - margin;
        float minY = totalHeight / 2 + margin;

        if (maxX <= minX || maxY <= minY)
            return;

        targetCenterX = minX + random.nextFloat() * (maxX - minX);
        targetCenterY = minY + random.nextFloat() * (maxY - minY);

        // Store target positions in tags
        positionCharacters(targetCenterX, targetCenterY, true);

        // Combine all character views
        List<TextView> allChars = new ArrayList<>();
        allChars.addAll(timeCharViews);
        allChars.addAll(amPmCharViews);
        allChars.addAll(dateCharViews);

        // Shuffle to randomize animation order
        List<Integer> indices = new ArrayList<>();
        for (int i = 0; i < allChars.size(); i++) {
            indices.add(i);
        }
        Collections.shuffle(indices, random);

        // Animate characters one by one in random order
        for (int i = 0; i < indices.size(); i++) {
            int charIndex = indices.get(i);
            TextView tv = allChars.get(charIndex);
            float[] targetPos = (float[]) tv.getTag();

            if (targetPos == null)
                continue;

            int delay = i * CHAR_STAGGER_DELAY;

            handler.postDelayed(() -> {
                animateCharacter(tv, targetPos[0], targetPos[1]);
            }, delay);
        }

        // Update current position after animation completes
        int totalAnimationTime = indices.size() * CHAR_STAGGER_DELAY + CHAR_ANIMATION_DURATION;
        handler.postDelayed(() -> {
            currentCenterX = targetCenterX;
            currentCenterY = targetCenterY;
        }, totalAnimationTime);
    }

    private void animateCharacter(TextView tv, float targetX, float targetY) {
        // Get current position
        float startX = tv.getX();
        float startY = tv.getY();

        // Create curved path animation
        PropertyValuesHolder pvhX = PropertyValuesHolder.ofFloat("x", startX, targetX);
        PropertyValuesHolder pvhY = PropertyValuesHolder.ofFloat("y", startY, targetY);

        ObjectAnimator moveAnim = ObjectAnimator.ofPropertyValuesHolder(tv, pvhX, pvhY);
        moveAnim.setDuration(CHAR_ANIMATION_DURATION);
        moveAnim.setInterpolator(new OvershootInterpolator(0.8f));

        // Scale animation - shrink then grow
        ObjectAnimator scaleXDown = ObjectAnimator.ofFloat(tv, "scaleX", 1f, 0.5f);
        ObjectAnimator scaleYDown = ObjectAnimator.ofFloat(tv, "scaleY", 1f, 0.5f);
        scaleXDown.setDuration(CHAR_ANIMATION_DURATION / 3);
        scaleYDown.setDuration(CHAR_ANIMATION_DURATION / 3);

        ObjectAnimator scaleXUp = ObjectAnimator.ofFloat(tv, "scaleX", 0.5f, 1f);
        ObjectAnimator scaleYUp = ObjectAnimator.ofFloat(tv, "scaleY", 0.5f, 1f);
        scaleXUp.setDuration(CHAR_ANIMATION_DURATION * 2 / 3);
        scaleYUp.setDuration(CHAR_ANIMATION_DURATION * 2 / 3);
        scaleXUp.setInterpolator(new OvershootInterpolator(1.5f));
        scaleYUp.setInterpolator(new OvershootInterpolator(1.5f));

        // Alpha animation - fade slightly during movement
        ObjectAnimator alphaDown = ObjectAnimator.ofFloat(tv, "alpha", 1f, 0.6f);
        alphaDown.setDuration(CHAR_ANIMATION_DURATION / 3);

        ObjectAnimator alphaUp = ObjectAnimator.ofFloat(tv, "alpha", 0.6f, 1f);
        alphaUp.setDuration(CHAR_ANIMATION_DURATION * 2 / 3);

        // Combine animations
        AnimatorSet scaleDown = new AnimatorSet();
        scaleDown.playTogether(scaleXDown, scaleYDown, alphaDown);

        AnimatorSet scaleUp = new AnimatorSet();
        scaleUp.playTogether(scaleXUp, scaleYUp, alphaUp);

        AnimatorSet scaleSet = new AnimatorSet();
        scaleSet.playSequentially(scaleDown, scaleUp);

        AnimatorSet fullAnim = new AnimatorSet();
        fullAnim.playTogether(moveAnim, scaleSet);
        fullAnim.start();
    }

    @Override
    public void onDetachedFromWindow() {
        super.onDetachedFromWindow();

        if (handler != null) {
            handler.removeCallbacks(updateTimeRunnable);
            handler.removeCallbacks(moveClockRunnable);
            handler.removeCallbacksAndMessages(null);
        }
    }
}
