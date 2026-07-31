// CGAssociateMouseAndMouseCursorPosition(false) 가 macOS 26.4 에서 실제로 커서를
// 얼리는지 격리 검증한다. deskflow 와 무관한 최소 재현 프로그램.
//
// A 구간: 연결 상태(정상) → 커서가 움직여야 한다
// B 구간: 분리 상태(freeze) → 커서가 멈춰야 한다
#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>
#include <unistd.h>

static void sample(const char *phase, double seconds)
{
  CGEventRef e = CGEventCreate(NULL);
  CGPoint start = CGEventGetLocation(e);
  CFRelease(e);

  double minX = start.x, maxX = start.x, minY = start.y, maxY = start.y;
  int samples = (int)(seconds * 50);
  for (int i = 0; i < samples; i++) {
    CGEventRef ev = CGEventCreate(NULL);
    CGPoint p = CGEventGetLocation(ev);
    CFRelease(ev);
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
    usleep(20000);
  }

  double spanX = maxX - minX, spanY = maxY - minY;
  printf("[%s] 시작=(%.0f,%.0f) 이동범위 x=%.0fpx y=%.0fpx  -> %s\n", phase, start.x, start.y, spanX, spanY,
         (spanX > 5 || spanY > 5) ? "커서 움직임" : "커서 정지");
  fflush(stdout);
}

int main(void)
{
  printf("이제 5초간 마우스를 계속 움직여 주세요 (A: 정상 구간)\n");
  fflush(stdout);
  sample("A 연결", 5.0);

  printf("계속 움직여 주세요 (B: freeze 구간 — 커서가 멈춰야 정상)\n");
  fflush(stdout);
  CGAssociateMouseAndMouseCursorPosition(false);
  sample("B 분리", 5.0);
  CGAssociateMouseAndMouseCursorPosition(true);

  printf("완료 (연결 복구됨)\n");
  return 0;
}
