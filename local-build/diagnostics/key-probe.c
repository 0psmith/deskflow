// key-probe — mac 키보드가 실제로 어떤 virtual keycode/flags 를 내는지 관찰한다.
//
// 목적: deskflow 가 클라이언트로 보내는 KeyID 를 결정하는 입력이 무엇인지 확인.
//       특히 한/영·한자 키와 Command/Option 의 실제 keycode.
//
// 빌드: clang -framework ApplicationServices -framework Carbon -o key-probe key-probe.c
// 실행: ./key-probe        (터미널에 "입력 모니터링" 권한 필요)
//
// deskflow 와 동일하게 CGEventTap(kCGSessionEventTap, listen-only)을 쓴다.

#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include <stdio.h>

// Carbon kVK_* 상수 중 이번 조사에 관련된 것만 이름을 붙인다.
static const char *vkName(CGKeyCode k)
{
  switch (k) {
  case kVK_Command:
    return "kVK_Command (Left Cmd)";
  case kVK_RightCommand:
    return "kVK_RightCommand";
  case kVK_Option:
    return "kVK_Option (Left Opt)";
  case kVK_RightOption:
    return "kVK_RightOption";
  case kVK_Control:
    return "kVK_Control";
  case kVK_RightControl:
    return "kVK_RightControl";
  case kVK_Shift:
    return "kVK_Shift";
  case kVK_RightShift:
    return "kVK_RightShift";
  case kVK_CapsLock:
    return "kVK_CapsLock";
  case kVK_Function:
    return "kVK_Function (fn)";
  case kVK_JIS_Eisu:
    return "kVK_JIS_Eisu (102) <- 한글 키보드의 '한자' 위치";
  case kVK_JIS_Kana:
    return "kVK_JIS_Kana (104) <- 한글 키보드의 '한/영' 위치";
  case kVK_Space:
    return "kVK_Space";
  default:
    return "";
  }
}

static void dumpFlags(CGEventFlags f)
{
  printf("  flags=0x%08llx [", (unsigned long long)f);
  if (f & kCGEventFlagMaskShift)
    printf("shift ");
  if (f & kCGEventFlagMaskControl)
    printf("control ");
  if (f & kCGEventFlagMaskAlternate)
    printf("alt/option ");
  if (f & kCGEventFlagMaskCommand)
    printf("command ");
  if (f & kCGEventFlagMaskAlphaShift)
    printf("capslock ");
  if (f & kCGEventFlagMaskSecondaryFn)
    printf("fn ");
  if (f & kCGEventFlagMaskNumericPad)
    printf("numpad ");
  // 좌/우 구분 비트 (IOKit NX_*MASK). CGEventFlags 에 그대로 실려 온다.
  if (f & 0x00000002)
    printf("L-shift ");
  if (f & 0x00000004)
    printf("R-shift ");
  if (f & 0x00000001)
    printf("L-control ");
  if (f & 0x00002000)
    printf("R-control ");
  if (f & 0x00000020)
    printf("L-option ");
  if (f & 0x00000040)
    printf("R-option ");
  if (f & 0x00000008)
    printf("L-command ");
  if (f & 0x00000010)
    printf("R-command ");
  printf("]\n");
}

static CGEventRef callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
  (void)proxy;
  (void)refcon;

  if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
    printf("[tap disabled — 재활성화]\n");
    return event;
  }

  CGKeyCode key = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
  CGEventFlags flags = CGEventGetFlags(event);
  int autorepeat = (int)CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat);

  const char *typeName = (type == kCGEventKeyDown)          ? "keyDown"
                         : (type == kCGEventKeyUp)          ? "keyUp"
                         : (type == kCGEventFlagsChanged)   ? "flagsChanged"
                                                            : "?";

  // 문자 표현 (있으면)
  UniChar chars[8] = {0};
  UniCharCount len = 0;
  CGEventKeyboardGetUnicodeString(event, 8, &len, chars);

  printf("%-13s keycode=%3u (0x%02x) %s", typeName, key, key, vkName(key));
  if (len > 0 && chars[0] >= 0x20 && chars[0] < 0x7f) {
    printf("  char='%c'", (char)chars[0]);
  } else if (len > 0) {
    printf("  char=U+%04X", chars[0]);
  }
  if (autorepeat)
    printf("  [repeat]");
  printf("\n");
  dumpFlags(flags);

  return event;
}

int main(void)
{
  CGEventMask mask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) |
                     CGEventMaskBit(kCGEventFlagsChanged);

  CFMachPortRef tap =
      CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly, mask, callback, NULL);
  if (!tap) {
    fprintf(stderr, "event tap 생성 실패 — 터미널에 '입력 모니터링' 권한을 주세요.\n");
    return 1;
  }

  CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
  CFRunLoopAddSource(CFRunLoopGetCurrent(), src, kCFRunLoopCommonModes);
  CGEventTapEnable(tap, true);

  printf("키를 눌러보세요 (Ctrl+C 로 종료).\n");
  printf("조사 대상: 한/영, 한자, 왼쪽/오른쪽 Command, 왼쪽/오른쪽 Option, Control, fn\n\n");
  CFRunLoopRun();
  return 0;
}
