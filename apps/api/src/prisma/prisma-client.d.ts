/**
 * @prisma/client runtime types are not generated in this environment (prisma install
 * postinstall was blocked, so `prisma generate` cannot run and no DB is available).
 * This declaration mirrors the @prisma/client surface that the services rely on so
 * `tsc --noEmit` passes strictly. At runtime the real @prisma/client package would
 * provide the implementation; here we type the subset used by the application.
 *
 * Geography columns are declared Unsupported("geography") in schema.prisma and are
 * reached through $queryRaw / $executeRaw, never through the typed repositories.
 */

export interface PrismaRepository<T> {
  findUnique(args: { where: any }): Promise<T | null>;
  findFirst(args: { where: any; orderBy?: any; include?: any }): Promise<T | null>;
  findMany(args?: {
    where?: any;
    orderBy?: any;
    take?: number;
    skip?: number;
    cursor?: any;
    include?: any;
  }): Promise<T[]>;
  create(args: { data: any }): Promise<T>;
  update(args: { where: any; data: any }): Promise<T>;
  updateMany(args: { where: any; data: any }): Promise<{ count: number }>;
  delete(args: { where: any }): Promise<T>;
  upsert(args: { where: any; create: any; update: any }): Promise<T>;
  count(args?: { where?: any }): Promise<number>;
  aggregate(args?: any): Promise<any>;
  $queryRaw(query: TemplateStringsArray, ...values: any[]): Promise<any>;
  $executeRaw(query: TemplateStringsArray, ...values: any[]): Promise<any>;
}

export interface PrismaClient {
  $connect(): Promise<void>;
  $disconnect(): Promise<void>;
  $transaction<T>(fn: (tx: PrismaClient) => Promise<T>): Promise<T>;
  $transaction<T>(promises: Promise<any>[]): Promise<T[]>;
  $queryRaw(query: TemplateStringsArray, ...values: any[]): Promise<any>;
  $executeRaw(query: TemplateStringsArray, ...values: any[]): Promise<any>;

  // Model repositories (subset used by the application)
  currencies: PrismaRepository<any>;
  serviceAreas: PrismaRepository<any>;
  dispatchSettings: PrismaRepository<any>;
  vehicleTypes: PrismaRepository<any>;
  documentTypes: PrismaRepository<any>;
  users: PrismaRepository<any>;
  userRoles: PrismaRepository<any>;
  otpChallenges: PrismaRepository<any>;
  refreshTokens: PrismaRepository<any>;
  deviceTokens: PrismaRepository<any>;
  customerProfiles: PrismaRepository<any>;
  savedPlaces: PrismaRepository<any>;
  driverProfiles: PrismaRepository<any>;
  vehicles: PrismaRepository<any>;
  driverDocuments: PrismaRepository<any>;
  pricingRules: PrismaRepository<any>;
  fixedRoutes: PrismaRepository<any>;
  rides: PrismaRepository<any>;
  rideEvents: PrismaRepository<any>;
  rideOffers: PrismaRepository<any>;
  driverLocationUpdates: PrismaRepository<any>;
  paymentRecords: PrismaRepository<any>;
  driverPayouts: PrismaRepository<any>;
  driverLedgerEntries: PrismaRepository<any>;
  ratings: PrismaRepository<any>;
  supportTickets: PrismaRepository<any>;
  supportTicketNotes: PrismaRepository<any>;
  notifications: PrismaRepository<any>;
  auditLogs: PrismaRepository<any>;
  idempotencyKeys: PrismaRepository<any>;
}

declare module '@prisma/client' {
  export class PrismaClient implements PrismaClient {
    constructor(options?: any);
    $connect(): Promise<void>;
    $disconnect(): Promise<void>;
    $transaction<T>(fn: (tx: PrismaClient) => Promise<T>): Promise<T>;
    $transaction<T>(promises: Promise<any>[]): Promise<T[]>;
    $queryRaw(query: TemplateStringsArray, ...values: any[]): Promise<any>;
    $executeRaw(query: TemplateStringsArray, ...values: any[]): Promise<any>;
    currencies: PrismaRepository<any>;
    serviceAreas: PrismaRepository<any>;
    dispatchSettings: PrismaRepository<any>;
    vehicleTypes: PrismaRepository<any>;
    documentTypes: PrismaRepository<any>;
    users: PrismaRepository<any>;
    userRoles: PrismaRepository<any>;
    otpChallenges: PrismaRepository<any>;
    refreshTokens: PrismaRepository<any>;
    deviceTokens: PrismaRepository<any>;
    customerProfiles: PrismaRepository<any>;
    savedPlaces: PrismaRepository<any>;
    driverProfiles: PrismaRepository<any>;
    vehicles: PrismaRepository<any>;
    driverDocuments: PrismaRepository<any>;
    pricingRules: PrismaRepository<any>;
    fixedRoutes: PrismaRepository<any>;
    rides: PrismaRepository<any>;
    rideEvents: PrismaRepository<any>;
    rideOffers: PrismaRepository<any>;
    driverLocationUpdates: PrismaRepository<any>;
    paymentRecords: PrismaRepository<any>;
    driverPayouts: PrismaRepository<any>;
    driverLedgerEntries: PrismaRepository<any>;
    ratings: PrismaRepository<any>;
    supportTickets: PrismaRepository<any>;
    supportTicketNotes: PrismaRepository<any>;
    notifications: PrismaRepository<any>;
    auditLogs: PrismaRepository<any>;
    idempotencyKeys: PrismaRepository<any>;
  }
}
