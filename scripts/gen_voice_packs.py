#!/usr/bin/env python3
"""
Generate all Rescue Me voice pack clips.
Usage: OPENAI_API_KEY=sk-... python3 scripts/gen_voice_packs.py

Produces 60 mixed MP3s (6 contacts × 5 lines × 2 languages) at:
  RescueMe/Resources/VoicePacks/{Pack}/{en|zh}/{pack}_{01-05}.mp3

Ambient bed: pink noise, louder than before (~-6 dB relative to voice).
"""

import subprocess
import sys
import os
from pathlib import Path
from openai import OpenAI

client = OpenAI()  # reads OPENAI_API_KEY from env

REPO = Path(__file__).parent.parent
VP = REPO / "RescueMe/Resources/VoicePacks"
AMB = VP / "_ambient_30s.mp3"

# Pad (silence tail) per clip slot, cycles 1-5
PADS = [3.5, 4.0, 4.5, 3.8, 4.2]

PACKS = {
    "Mom": {
        "en": ("shimmer", [
            "Hey, it's me. Are you almost done?",
            "I'm at the store — do we need anything else?",
            "Okay, I'll be home in a bit. Drive safe.",
            "Are you eating okay? I made soup.",
            "Call me when you get this. Love you.",
        ]),
        "zh": ("nova", [
            "喂？喂？你聽得到嗎？",
            "訊號有點差喔寶貝",
            "你在忙嗎？我想問你一下事情",
            "我在超市啦，等等再打給你",
            "好啦，愛你喔，掰掰",
        ]),
    },
    "Dad": {
        "en": ("onyx", [
            "Hey buddy, you got a sec?",
            "Yeah? Hello, can you hear me?",
            "It's kinda loud here — did you get my text?",
            "Just wanted to check in real quick",
            "Alright, call me back when you can. Bye.",
        ]),
        "zh": ("onyx", [
            "喂，你現在方便講話嗎？",
            "有空嗎？就想跟你講兩句",
            "這邊有點吵，你聽得清楚嗎？",
            "沒什麼事啦，就問一下",
            "好，你忙完再回我",
        ]),
    },
    "Boss": {
        "en": ("echo", [
            "Hey, quick — are you at your desk?",
            "I need you on a call in five, can you make it?",
            "Sorry to bug you, the client just called.",
            "Where are you right now?",
            "Actually, forget it. I'll handle it. Talk later.",
        ]),
        "zh": ("alloy", [
            "欸，你現在有空嗎？",
            "有件事情想跟你確認一下",
            "五分鐘後可以開個會嗎？",
            "客戶剛打來，有點急",
            "算了我自己處理，晚點聊",
        ]),
    },
    "DrChen": {
        "en": ("alloy", [
            "Hi, this is Dr. Chen's office calling about your appointment.",
            "Yes, hello — is this the patient?",
            "We had a cancellation and can move your appointment up.",
            "Can you come in tomorrow morning at nine?",
            "Just leave a message when you get this. Thanks.",
        ]),
        "zh": ("nova", [
            "喂，您好，這裡是陳醫師診所",
            "請問是本人嗎？",
            "我們這邊有個空檔可以幫您提前",
            "明天早上九點方便過來嗎？",
            "如果不方便，麻煩再回電給我們，謝謝",
        ]),
    },
    "Emergency": {
        "en": ("nova", [
            "Hey, everything okay? I got your message.",
            "Are you safe? Where are you?",
            "Do you need me to come get you?",
            "Stay on the line, I'm heading over.",
            "I'm five minutes away, just breathe.",
        ]),
        "zh": ("shimmer", [
            "喂？你還好嗎？我看到你的訊息",
            "你現在在哪？安全嗎？",
            "需要我過去接你嗎？",
            "電話不要掛，我現在過去",
            "我五分鐘就到，深呼吸",
        ]),
    },
    "Unknown": {
        "en": ("fable", [
            "Hello? Hello, can you hear me?",
            "Yes hi, sorry — is this the right number?",
            "This is a courtesy call regarding your account.",
            "Hello? I think the line is bad.",
            "Sorry, wrong number I think. Bye.",
        ]),
        "zh": ("echo", [
            "喂？喂？聽得到嗎？",
            "呃，請問是...",
            "您好，這裡是關於您...",
            "喂？訊號好像不太好",
            "不好意思打錯電話了，掰",
        ]),
    },
}


def gen_ambient():
    print("Generating ambient bed…")
    # Louder pink noise: voice ~1.0, ambient ~0.55 → roughly -5 dB relative to voice.
    # Two noise sources layered: primary crowd murmur + subtle high-freq presence.
    subprocess.run([
        "ffmpeg", "-y",
        "-f", "lavfi", "-i", "anoisesrc=color=pink:sample_rate=22050:amplitude=0.85",
        "-f", "lavfi", "-i", "anoisesrc=color=white:sample_rate=22050:amplitude=0.15",
        "-filter_complex",
        "[0:a]lowpass=f=650,highpass=f=90,volume=0.80[crowd];"
        "[1:a]lowpass=f=4000,highpass=f=800,volume=0.25[hiss];"
        "[crowd][hiss]amix=inputs=2:duration=shortest,"
        "tremolo=f=0.25:d=0.18,"
        "atrim=duration=30[out]",
        "-map", "[out]",
        "-ar", "22050", "-ac", "1", "-b:a", "128k",
        str(AMB),
    ], check=True, capture_output=True)
    print(f"  → {AMB.name}")


def gen_tts(text: str, voice: str, output: Path):
    response = client.audio.speech.create(
        model="tts-1-hd",
        voice=voice,
        input=text,
        response_format="mp3",
    )
    output.write_bytes(response.content)


def mix_clip(raw: Path, output: Path, pad: float):
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", str(raw)],
        capture_output=True, text=True, check=True,
    )
    vdur = float(result.stdout.strip())
    total = vdur + pad
    fade_out = max(0.0, total - 0.35)
    subprocess.run([
        "ffmpeg", "-y",
        "-stream_loop", "-1", "-i", str(AMB),
        "-i", str(raw),
        "-filter_complex",
        f"[0:a]atrim=duration={total:.3f},volume=0.55[amb];"
        f"[1:a]volume=1.0,apad=pad_dur={pad:.1f}[vpad];"
        "[amb][vpad]amix=inputs=2:duration=longest,"
        f"afade=t=in:st=0:d=0.25,"
        f"afade=t=out:st={fade_out:.3f}:d=0.30[out]",
        "-map", "[out]",
        "-ar", "22050", "-ac", "1", "-b:a", "128k",
        str(output),
    ], check=True, capture_output=True)


def main():
    if not os.environ.get("OPENAI_API_KEY"):
        print("ERROR: OPENAI_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    gen_ambient()

    total_clips = sum(len(langs) * 5 for langs in PACKS.values())
    done = 0

    for pack_name, langs in PACKS.items():
        for lang, (voice, lines) in langs.items():
            folder = VP / pack_name / lang
            folder.mkdir(parents=True, exist_ok=True)
            prefix = pack_name.lower()  # mom, dad, boss, drchen, emergency, unknown

            for i, line in enumerate(lines, 1):
                raw = folder / f"_raw_{i:02d}.mp3"
                out = folder / f"{prefix}_{i:02d}.mp3"

                done += 1
                print(f"[{done}/{total_clips}] {pack_name}/{lang}/{i}: {line[:45]}…")

                gen_tts(line, voice, raw)
                mix_clip(raw, out, PADS[i - 1])
                raw.unlink()

    AMB.unlink()
    print(f"\nDone — {done} clips generated.")


if __name__ == "__main__":
    main()
