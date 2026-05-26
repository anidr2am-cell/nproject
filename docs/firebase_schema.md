# Firebase Schema Draft

Nproject uses Firebase Auth for account identity, Cloud Firestore for marketplace data, and Firebase Storage for listing photos.

## users/{uid}

- name: string, required
- nickname: string, required
- email: string, required, used as login ID
- residence: string?, city or province such as Bangkok, Pattaya, Chiang Mai
- kakaoId: string?
- lineId: string?
- phoneCountry: "TH" | "KR"?
- phoneNumber: string?
- tradeCount: number, public
- createdAt: timestamp
- updatedAt: timestamp

## listings/{listingId}

- sellerId: string
- sellerNickname: string
- sellerTradeCount: number
- type: "used" | "request" | "currency"
- title: string, required
- category: string, required
- priceText: string, required
- description: string, required
- placeText: string, required
- photoUrls: string[], max 5
- status: "active" | "reserved" | "completed" | "hidden"
- createdAt: timestamp
- updatedAt: timestamp

## listing_contacts/{listingId}/views/{viewerId}

Optional audit trail for "contact reveal" behavior if the app later limits contact views.

- viewerId: string
- viewedAt: timestamp

## Storage

- listings/{listingId}/{index}.jpg
- profile_photos/{uid}.jpg

## Security Direction

- Public users should see nickname, residence, and tradeCount only.
- Users can create listings only under their own uid.
- Users can update or hide only their own listings.
- `tradeCount` should be changed by a trusted backend path later, not directly by clients.
