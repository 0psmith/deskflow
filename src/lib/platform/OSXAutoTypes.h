/*
 * Deskflow -- mouse and keyboard sharing utility
 * SPDX-FileCopyrightText: (C) 2022 Symless Ltd.
 * SPDX-License-Identifier: GPL-2.0-only WITH LicenseRef-OpenSSL-Exception
 */
#pragma once

#if WINAPI_CARBON
#include <Carbon/Carbon.h>
#include <memory>
#include <mutex>

using CFDeallocator = decltype(&CFRelease);
using AutoCFArray = std::unique_ptr<const __CFArray, CFDeallocator>;
using AutoCFDictionary = std::unique_ptr<const __CFDictionary, CFDeallocator>;
using AutoCFString = std::unique_ptr<const __CFString, CFDeallocator>;
using AutoTISInputSourceRef = std::unique_ptr<__TISInputSource, CFDeallocator>;

// TIS API 는 스레드 세이프하지 않다. upstream master 가 도입한 것과 같은 이름을 쓴다.
inline std::mutex g_tisMutex;

#endif
