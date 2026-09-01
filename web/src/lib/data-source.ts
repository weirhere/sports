// Toggle between mock data and ESPN API
// Set USE_ESPN=true in .env.local to use the real ESPN API

export function useEspnApi(): boolean {
  return process.env.USE_ESPN === "true";
}
