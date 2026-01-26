/**
 * Takes an object of { key: value } and builds a URL param string.
 * e.g. { page: 1, limit: 10 } -> ?page=1&limit=10
 */
export const constructUrlSearchParams = (
    object: Record<string, string | boolean | undefined>,
  ): string => {
    const searchParams = new URLSearchParams();
  
    for (const key in object) {
      const value = object[key];
      if (value !== undefined) {
        searchParams.set(key, String(value));
      }
    }
  
    return `?${searchParams.toString()}`;
  };
  
  /** Checks whether we have a next page */
  export const getNextPageParam = (lastPage: any) => {
    if ("api" in lastPage) {
      return lastPage.api.cursor;
    }
    return lastPage.cursor;
  };