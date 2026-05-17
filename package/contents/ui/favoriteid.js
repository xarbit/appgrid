// SPDX-FileCopyrightText: 2026 AppGrid Contributors
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Helpers for KAStats favorite ids. Favorites are stored prefixed with the
// "applications:" scheme; the rest of AppGrid works with bare storage ids
// (basename of the .desktop file). Centralising the conversion here avoids
// scattering the prefix string and its magic length around the codebase.
//
// Import as:
//     import "favoriteid.js" as FavoriteId

.pragma library

const SCHEME = "applications:"

// Returns `id` with the scheme prepended if it doesn't already have one.
// `null` / `undefined` / empty become the bare scheme.
function toPrefixed(id) {
    if (!id) return SCHEME
    return id.indexOf(":") >= 0 ? id : SCHEME + id
}

// Returns `id` with the scheme stripped if present, otherwise unchanged.
function stripPrefix(id) {
    if (typeof id !== "string") return ""
    return id.startsWith(SCHEME) ? id.substring(SCHEME.length) : id
}

function hasPrefix(id) {
    return typeof id === "string" && id.startsWith(SCHEME)
}
