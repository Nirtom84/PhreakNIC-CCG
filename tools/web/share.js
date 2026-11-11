// Result-card sharing for the web build. Loaded as a same-origin file so the site's
// Content-Security-Policy can keep forbidding eval; the game calls it through JavaScriptBridge.get_interface.
window.pnShare = {
  file: null,
  // Builds the PNG File from base64 and reports whether this browser can share files.
  prepare(base64, name) {
    try {
      const text = atob(base64);
      const bytes = new Uint8Array(text.length);
      for (let i = 0; i < text.length; i++) bytes[i] = text.charCodeAt(i);
      this.file = new File([bytes], name, { type: 'image/png' });
      return !!(navigator.share && navigator.canShare && navigator.canShare({ files: [this.file] }));
    } catch (e) { return false; }
  },
  share(text) {
    try {
      if (this.file) navigator.share({ files: [this.file], title: 'PhreakNIC CCG', text }).catch(() => {});
    } catch (e) {}
  },
};
