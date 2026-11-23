# 음성 인식 모델

앱에 넣는 Whisper 모델 파일을 이 폴더에 둔다. 파일이 커서 git에는 넣지 않는다.

빌드 전에 받아 두기:

```powershell
curl.exe -L -o assets/models/ggml-base-q5_1.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin
```

어떤 모델을 쓰는지와 그 이유는 `docs/decisions/speech-engine.md`에 적는다.
