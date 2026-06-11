const cloudinary = require("../config/cloudinary");

// يولّد رابط عرض مؤقت — صالح ساعة واحدة بالافتراضي
function generateSignedUrl(publicId, mediaType = "image", expiresInSeconds = 3600) {
  if (!publicId) return null;

  const expiresAt    = Math.floor(Date.now() / 1000) + expiresInSeconds;
  const resourceType = mediaType === "video" ? "video" : "image";
  const format       = mediaType === "video" ? "mp4" : "jpg";

  return cloudinary.utils.private_download_url(publicId, format, {
    resource_type: resourceType,
    type:          "authenticated",
    expires_at:    expiresAt,
    attachment:    false,
  });
}

// يولّد رابط تحميل مؤقت — صالح 30 دقيقة فقط
function generateSignedDownloadUrl(publicId, mediaType = "image", expiresInSeconds = 1800) {
  if (!publicId) return null;

  const expiresAt    = Math.floor(Date.now() / 1000) + expiresInSeconds;
  const resourceType = mediaType === "video" ? "video" : "image";
  const format       = mediaType === "video" ? "mp4" : "jpg";

  return cloudinary.utils.private_download_url(publicId, format, {
    resource_type: resourceType,
    type:          "authenticated",
    expires_at:    expiresAt,
    attachment:    true,
  });
}

// يحوّل كل الـ items ويستبدل الروابط الحقيقية بروابط مؤقتة
function signGalleryItems(items, expiresInSeconds = 3600) {
  if (!Array.isArray(items)) return [];

  return items.map((item) => {
    const mediaType = item.media_type || "image";
    const publicId  = item.cloudinary_public_id;

    const signedUrl = publicId
      ? generateSignedUrl(publicId, mediaType, expiresInSeconds)
      : item.media_url;

    return {
      ...item,
      media_url:            signedUrl,
      thumbnail_url:        signedUrl,
      original_url:         undefined,
      cloudinary_public_id: undefined,
    };
  });
}

module.exports = {
  generateSignedUrl,
  generateSignedDownloadUrl,
  signGalleryItems,
}; 


