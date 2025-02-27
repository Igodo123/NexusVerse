;; NexuVaz Platform Smart Contract
;; Handles in-game asset ownership and trading functionality

;; Constants
(define-constant admin-owner tx-sender)
(define-constant error-admin-only (err u100))
(define-constant error-not-found (err u101))
(define-constant error-not-authorized (err u102))
(define-constant error-invalid-input (err u103))
(define-constant error-invalid-price (err u104))
(define-constant level-cap u100)
(define-constant exp-cap u10000)
(define-constant metadata-max-length u256)
(define-constant max-operation-size u10)  ;; Limit batch operations to prevent potential gas issues

;; Data Variables
(define-map nft-items 
    { item-id: uint }
    { holder: principal, metadata-uri: (string-utf8 256), tradeable: bool })

(define-map item-values
    { item-id: uint }
    { value: uint })

(define-map user-progress
    { user: principal }
    { exp: uint, rank: uint })

(define-map bazaar-listings
    { item-id: uint }
    { vendor: principal, value: uint, posted-at: uint })

;; Item Counter
(define-data-var item-counter uint u0)

;; Helper Functions

;; Validate item exists and return item data
(define-private (get-item-checked (item-id uint))
    (let ((item (map-get? nft-items { item-id: item-id })))
        (asserts! (and 
                (is-some item)
                (<= item-id (var-get item-counter)))
            error-not-found)
        (ok (unwrap-panic item))))

;; Validate metadata URI length
(define-private (validate-metadata-uri (uri (string-utf8 256)))
    (let ((uri-length (len uri)))
        (and 
            (> uri-length u0)
            (<= uri-length metadata-max-length))))

;; Public Functions

;; Batch Mint new gaming items
(define-public (batch-mint-items 
    (metadata-uris (list 10 (string-utf8 256))) 
    (tradeable-list (list 10 bool)))
    (begin
        (asserts! (is-eq tx-sender admin-owner) error-admin-only)
        (asserts! (and 
            (> (len metadata-uris) u0)
            (<= (len metadata-uris) max-operation-size)
            (is-eq (len metadata-uris) (len tradeable-list))) 
            error-invalid-input)
        (let ((minted-items 
            (map mint-single-item 
                metadata-uris 
                tradeable-list)))
            (ok minted-items))))

;; Helper function for batch minting
(define-private (mint-single-item 
    (uri (string-utf8 256))
    (tradeable bool))
    (let 
        ((item-id (+ (var-get item-counter) u1)))
        (asserts! (validate-metadata-uri uri) error-invalid-input)
        (map-set nft-items
            { item-id: item-id }
            { holder: admin-owner,
              metadata-uri: uri,
              tradeable: tradeable })
        (var-set item-counter item-id)
        (ok item-id)))

;; Batch Transfer items
(define-public (batch-transfer-items 
    (item-ids (list 10 uint)) 
    (recipients (list 10 principal)))
    (begin
        (asserts! (and 
            (> (len item-ids) u0)
            (<= (len item-ids) max-operation-size)
            (is-eq (len item-ids) (len recipients))) 
            error-invalid-input)
        (let ((transfers 
            (map transfer-single-item 
                item-ids 
                recipients)))
            (ok transfers))))

;; Helper function for batch transfer
(define-private (transfer-single-item 
    (item-id uint)
    (recipient principal))
    (let 
        ((item (unwrap-panic (get-item-checked item-id))))
        (asserts! (and
                (is-eq (get holder item) tx-sender)
                (get tradeable item)
                (not (is-eq recipient tx-sender)))  ;; Prevent self-transfers
            error-not-authorized)
        (map-set nft-items
            { item-id: item-id }
            { holder: recipient,
              metadata-uri: (get metadata-uri item),
              tradeable: (get tradeable item) })
        (ok true)))


;; Mint single item
(define-public (mint-item (metadata-uri (string-utf8 256)) (tradeable bool))
    (let
        ((item-id (+ (var-get item-counter) u1)))
        (asserts! (is-eq tx-sender admin-owner) error-admin-only)
        (asserts! (validate-metadata-uri metadata-uri) error-invalid-input)
        (map-set nft-items
            { item-id: item-id }
            { holder: tx-sender,
              metadata-uri: metadata-uri,
              tradeable: tradeable })
        (var-set item-counter item-id)
        (ok item-id)))

;; Transfer item ownership
(define-public (transfer-item (item-id uint) (recipient principal))
    (begin
        (asserts! (<= item-id (var-get item-counter)) error-invalid-input)
        (let ((item (try! (get-item-checked item-id))))
            (asserts! (and
                    (is-eq (get holder item) tx-sender)
                    (get tradeable item)
                    (not (is-eq recipient tx-sender)))  ;; Prevent self-transfers
                error-not-authorized)
            (map-set nft-items
                { item-id: item-id }
                { holder: recipient,
                  metadata-uri: (get metadata-uri item),
                  tradeable: (get tradeable item) })
            (ok true))))

;; List item for sale with enhanced bazaar listing
(define-public (list-item-for-sale (item-id uint) (value uint))
    (begin
        (asserts! (<= item-id (var-get item-counter)) error-invalid-input)
        (let ((item (try! (get-item-checked item-id))))
            (asserts! (and 
                    (is-eq (get holder item) tx-sender)
                    (> value u0)
                    (get tradeable item))  ;; Ensure item is tradeable
                error-invalid-price)
            (map-set bazaar-listings
                { item-id: item-id }
                { vendor: tx-sender, 
                  value: value, 
                  posted-at: block-height })
            (ok true))))

;; Purchase listed item with enhanced bazaar mechanics
(define-public (purchase-item (item-id uint))
    (begin
        (asserts! (<= item-id (var-get item-counter)) error-invalid-input)
        (let
            ((item (try! (get-item-checked item-id)))
             (listing (unwrap! (map-get? bazaar-listings { item-id: item-id }) error-not-found)))
            (asserts! (and
                    (not (is-eq (get vendor listing) tx-sender))
                    (get tradeable item))
                error-not-authorized)
            (try! (stx-transfer? (get value listing) tx-sender (get vendor listing)))
            (map-set nft-items
                { item-id: item-id }
                { holder: tx-sender,
                  metadata-uri: (get metadata-uri item),
                  tradeable: (get tradeable item) })
            (map-delete bazaar-listings { item-id: item-id })
            (ok true))))

;; Remove item from bazaar listing
(define-public (delist-item (item-id uint))
    (begin
        ;; Validate item-id is within the range of minted items
        (asserts! (<= item-id (var-get item-counter)) error-invalid-input)
        
        ;; Try to get the listing, return error if not found
        (let ((listing (unwrap! (map-get? bazaar-listings { item-id: item-id }) error-not-found)))
            ;; Ensure only the vendor can delist
            (asserts! (is-eq tx-sender (get vendor listing)) error-not-authorized)
            
            ;; Delete the bazaar listing
            (map-delete bazaar-listings { item-id: item-id })
            
            ;; Return success
            (ok true))))

;; Update user progress with validation
(define-public (update-user-progress (exp uint) (rank uint))
    (begin
        (asserts! (<= exp exp-cap) error-invalid-input)
        (asserts! (<= rank level-cap) error-invalid-input)
        (map-set user-progress
            { user: tx-sender }
            { exp: exp, rank: rank })
        (ok true)))

;; Read-only Functions

;; Get item details
(define-read-only (get-item-details (item-id uint))
    (if (<= item-id (var-get item-counter))
        (map-get? nft-items { item-id: item-id })
        none))

;; Get bazaar listing details
(define-read-only (get-bazaar-listing (item-id uint))
    (map-get? bazaar-listings { item-id: item-id }))

;; Get user progress
(define-read-only (get-user-progress (user principal))
    (map-get? user-progress { user: user }))

;; Get total items minted
(define-read-only (get-total-items)
    (var-get item-counter)) 