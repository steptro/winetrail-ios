import Foundation

/// Generic pagination wrapper mapping from Spring Boot's Page response structure.
///
/// The backend returns paginated responses with `content`, `totalPages`, `totalElements`,
/// `number` (current page), and `last` fields. This struct provides a clean Swift interface
/// for ViewModels to consume paginated data regardless of the underlying element type.
struct PagedResult<T> {
    let content: [T]
    let totalPages: Int
    let totalElements: Int
    let currentPage: Int
    let isLast: Bool
}
