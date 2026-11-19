extends RefCounted
## Four original, short mono cues. Each is rendered once and uses the
## existing SFX pool. Frequencies give the warnings presence on phone speakers.
const SAMPLE_RATE := 22050
static var cues: Array[AudioStreamWAV] = []

static func build() -> Array[AudioStreamWAV]:
    if not cues.is_empty():
        return cues
    # Each voice is a group of [onset, duration, start Hz, end Hz, overtones].
    # Wood: two dry knocks; ice: descending chimes; piston: a rising steel
    # alarm; vent: a single breathy lift. All have short fades and no loops.
    var voices := [
        [[0.0,0.11,720.0,360.0,0.16],[0.105,0.14,850.0,440.0,0.17]],
        [[0.0,0.16,1230.0,1040.0,0.20],[0.12,0.19,880.0,720.0,0.24]],
        [[0.0,0.14,520.0,660.0,0.40],[0.10,0.21,660.0,905.0,0.36]],
        [[0.0,0.28,350.0,820.0,0.24]]
    ]
    var names := ["Wood clack","Ice chimes","Piston alarm","Vent hiss"]
    for index in range(voices.size()):
        cues.append(render(voices[index],0.32,names[index],index == 1,index == 3))
    return cues

static func render(notes: Array, duration: float, label: String, chime := false, airy := false) -> AudioStreamWAV:
    var mix := PackedFloat32Array()
    mix.resize(roundi(SAMPLE_RATE*duration))
    for note in notes:
        var start: int = roundi(note[0]*SAMPLE_RATE)
        var frames: int = roundi(note[1]*SAMPLE_RATE)
        for frame in range(frames):
            var t := float(frame)/SAMPLE_RATE
            var progress := float(frame)/frames
            var phase: float = TAU*t*(note[2]+(note[3]-note[2])*progress*0.5)
            var envelope := minf(1.0,t*500.0)*pow(1.0-progress,1.8)
            var fundamental := sin(phase)
            var overtone: float = sin(phase*(2.72 if chime else 2.05))*note[4]
            # Close-spaced upper partials make the vent sound airy.
            var air := sin(phase*3.14)*sin(phase*1.13)*0.29 if airy else 0.0
            mix[start+frame] += 0.63*envelope*(fundamental+overtone+air)
    var pcm := PackedByteArray()
    pcm.resize(mix.size()*2)
    for frame in range(mix.size()):
        pcm.encode_s16(frame*2,roundi(clampf(mix[frame],-0.92,0.92)*32767.0))
    var clip := AudioStreamWAV.new()
    clip.format = AudioStreamWAV.FORMAT_16_BITS
    clip.mix_rate = SAMPLE_RATE
    clip.data = pcm
    clip.resource_name = label
    return clip
