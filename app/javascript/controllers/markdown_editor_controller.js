import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"
import "easymde"

// A markdown editor (EasyMDE) for a textarea. Files pasted, dropped, or picked with the toolbar's upload
// button are direct-uploaded to ActiveStorage, then linked from the text: images as ![name](url), other
// files as [name](url). The model attaches linked files when the record is saved.
export default class extends Controller {
  static values = { uploadUrl: String }

  connect() {
    this.editor = new window.EasyMDE({
      element: this.element,
      forceSync: true,
      spellChecker: false,
      status: ["upload-image"],
      uploadImage: true,
      imageAccept: "image/png, image/jpeg, image/gif, image/webp, application/pdf",
      imageMaxSize: 20 * 1024 * 1024,
      imageUploadFunction: (file, onSuccess, onError) => this.upload(file, onSuccess, onError),
      toolbar: [
        "bold", "italic", "heading", "|", "quote", "unordered-list", "ordered-list", "|",
        "link", "upload-image", "table", "|", "preview", "side-by-side", "fullscreen", "|", "guide"
      ]
    })
  }

  disconnect() {
    // Restore the plain textarea so Turbo's page cache doesn't snapshot (and later double up) the editor.
    this.editor?.toTextArea()
    this.editor?.cleanup()
    this.editor = null
  }

  upload(file, onSuccess, onError) {
    new DirectUpload(file, this.uploadUrlValue).create((error, blob) => {
      if (error) {
        onError(`Couldn't upload ${file.name}: ${error}`)
      } else {
        onSuccess(`/rails/active_storage/blobs/redirect/${blob.signed_id}/${encodeURIComponent(blob.filename)}`)
      }
    })
  }
}
