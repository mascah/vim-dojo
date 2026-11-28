export type Issue = { field: string; message: string };

const EMAIL = /^[^@\s]+@[^@\s]+\.[a-z]{2,}$/i;

export interface Signup {
  email: string;
  password: string;
  displayName: string;
  country: string;
}

export function validate(form: Signup): Issue[] {
  const issues: Issue[] = [];
  if (!EMAIL.test(form.email)) {
    issues.push({ field: "email", message: "Enter an email address like name@example.com" });
  }
  if (form.password.length < 12) {
    issues.push({ field: "password", message: "Use at least 12 characters" });
  }
  if (form.password.toLowerCase() === form.password) {
    issues.push({ field: "password", message: "Add at least one capital letter" });
  }
  if (form.displayName.trim() === "") {
    issues.push({ field: "displayName", message: "Choose a display name" });
  }
  if (!["GB", "IE", "NL", "DE"].includes(form.country)) {
    issues.push({ field: "country", message: "We do not ship there yet" });
  }
  return issues;
}

export const firstIssue = (issues: Issue[], field: string) =>
  issues.find((issue) => issue.field === field)?.message ?? "";
