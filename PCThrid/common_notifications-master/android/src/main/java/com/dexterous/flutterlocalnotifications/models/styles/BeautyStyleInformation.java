package com.dexterous.flutterlocalnotifications.models.styles;

import androidx.annotation.Keep;
import androidx.annotation.NonNull;

@Keep
public class BeautyStyleInformation extends DefaultStyleInformation {
    @NonNull
    public String title;
    @NonNull
    public String body;
    @NonNull
    public String image;
    @NonNull
    public String button;
    @NonNull
    public String appIcon;
    public String template = "";
    public String amount = "";

    /** 旧存档的已移除模板统一使用现存提醒样式，保留其通道和点击目标。 */
    public void normalizeTemplate() {
        if ("payout".equals(template)) {
            template = "goal";
            button = "Claim";
        }
    }

    public BeautyStyleInformation(@NonNull String title, @NonNull String body, @NonNull String image,
                                  @NonNull String button, @NonNull String appIcon) {
        super(false, false);
        this.title = title;
        this.body = body;
        this.image = image;
        this.button = button;
        this.appIcon = appIcon;
    }
}
