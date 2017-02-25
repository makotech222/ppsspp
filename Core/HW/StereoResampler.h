// Copyright (c) 2015- PPSSPP Project and Dolphin Project.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 2.0 or later versions.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License 2.0 for more details.

// A copy of the GPL 2.0 should have been included with the program.
// If not, see http://www.gnu.org/licenses/

// Official git repository and contact information can be found at
// https://github.com/hrydgard/ppsspp and http://www.ppsspp.org/.

// Adapted from Dolphin.

#pragma once

#include <string>
#include <memory>

#include "base/mutex.h"

#include "Common/ChunkFile.h"
#include "Common/CommonTypes.h"

#include "Core/HW/AsyncAudioQueue.h"


class StereoResampler : public AsyncAudioQueue {
public:
	StereoResampler();

	// Called from audio threads
	unsigned int Mix(short* samples, unsigned int numSamples, bool consider_framelimit, int sampleRate) override;

	// Called from main thread
	// This clamps the samples to 16-bit before starting to work on them.
	void PushSamples(const s32* samples, unsigned int num_samples) override;

	void GetAudioDebugStats(AudioDebugStats *stats) override;
	void Clear() override;

protected:
	void UpdateBufferSize();
	void SetInputSampleRate(unsigned int rate);

	int m_bufsize;
	int m_lowwatermark;
	unsigned int m_input_sample_rate;
	std::unique_ptr<int16_t[]> m_buffer;
	volatile u32 m_indexW;
	volatile u32 m_indexR;
	float m_numLeftI;
	u32 m_frac;
	int underrunCount_;
	int overrunCount_;
	float sample_rate_;
	int lastBufSize_;
	int lastPushSize_;
};
