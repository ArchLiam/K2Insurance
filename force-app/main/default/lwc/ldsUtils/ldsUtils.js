/**
 * @description Shared helpers for reducing Apex/LDS/JS error shapes into readable messages.
 * @author Liam Jeong <liam.jeong@5sinfusion.com>
 */

/**
 * @description Flattens the various Apex/LDS/JS error shapes into an array of readable messages.
 * @param {*} errors A single error or an array of errors from a wire/imperative call.
 * @return {String[]} The de-duplicated, non-empty human-readable messages.
 */
export function reduceErrors(errors) {
    if (!Array.isArray(errors)) {
        errors = [errors];
    }

    return (
        errors
            .filter((error) => !!error)
            .map((error) => {
                if (Array.isArray(error.body)) {
                    return error.body.map((e) => e.message);
                } else if (error?.body?.pageErrors?.length) {
                    return error.body.pageErrors.map((e) => e.message);
                } else if (
                    error?.body?.fieldErrors &&
                    Object.keys(error.body.fieldErrors).length > 0
                ) {
                    const fieldErrors = [];
                    Object.values(error.body.fieldErrors).forEach((errorArray) => {
                        fieldErrors.push(...errorArray.map((e) => e.message));
                    });
                    return fieldErrors;
                } else if (error?.body?.output?.errors?.length) {
                    return error.body.output.errors.map((e) => e.message);
                } else if (
                    error?.body?.output?.fieldErrors &&
                    Object.keys(error.body.output.fieldErrors).length > 0
                ) {
                    const fieldErrors = [];
                    Object.values(error.body.output.fieldErrors).forEach((errorArray) => {
                        fieldErrors.push(...errorArray.map((e) => e.message));
                    });
                    return fieldErrors;
                } else if (typeof error?.body?.message === 'string') {
                    return error.body.message;
                } else if (typeof error?.message === 'string') {
                    return error.message;
                }
                return error.statusText;
            })
            .reduce((prev, curr) => prev.concat(curr), [])
            .filter((message) => !!message)
    );
}
