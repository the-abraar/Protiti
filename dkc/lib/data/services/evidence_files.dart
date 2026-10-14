/// Every encrypted evidence file (photo, audio) ends in this, so one rule
/// finds them all for the wipe.
const evidenceExt = '.enc';

/// Plaintext audio exists only while a recording runs, in the private
/// documents directory. It is encrypted on stop, or recovered at the next launch.
const recordingExt = '.m4a';

/// Extensions written by earlier builds. The wipe still removes them.
const legacyEvidenceExts = ['.bin', '.tmp', '.enc_audio'];
