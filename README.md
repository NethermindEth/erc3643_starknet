
{
    "TREXGateway.sol": [
        "ITREXGateway.sol", 
        "AgentRole.sol",
        "@openzeppelin/Strings.sol",
        "@openzeppelin/IERC20.sol",
    ],
    "ITREXGateway.sol" : ["ITREXFactory.sol"],
    "ITREXFactory.sol": [],
    "TREXFactory": [
        "AgentRole.sol",
        "IToken.sol"
        "IClamTopicsRegistry.sol",
        "IIdentityRegistry.sol",
        "IModularCompliance.sol",
        "ITrustedIssuersRegistry.sol",
        "IIdentityRegistryStorage.sol",
        "ITREXImplementation.sol",
        "TokenProxy.sol",
        "ClaimTopicsRegistryProxy.sol",
        "IdentityRegistryProxy.sol",
        "IdentityRegistryStorageProxy.sol"
        "TrustedIssuersRegistryProxy.sol",
        "ModularComplianceProxy.sol",
        "ITREXFactory.sol",
        "@onchain-id/IIdFactory.sol",
    ],
    

    "IDVATransferManager.sol" : ["AgentRole.sol", "IToken.sol"],
    "DVATransferManager.sol": ["AgentRole.sol", "IToken.sol", "IDVATransferManager.sol"],


    "DVDTransferManager.sol": [
        "AgentRole.sol",
        "IToken.sol"
    ],


    "ClaimTopicsRegistry.sol": ["@openzeppelin/OwnableUpgradeable.sol",
    "CTRStorage.sol",
    "IClaimTopicsRegistry.sol"
    ],
    "IdentityRegistry.sol": ["@onchain-id/IClaimIssuer.sol","@onchain-id/IIdentity.sol", "IClaimTopicsRegistry.sol","ITrustedIssuersRegistry.sol", "IIdentityRegistry.sol",
    "AgentRoleUpgradeable.sol","IIdentityRegistryStorage.sol", "IRSStorage.sol"],
    "IdentityRegistryStorage.sol": ["@onchain-id/IIdentity.sol", "AgentRoleUpgradeable.sol", "IIdentityRegistryStorage.sol", "IRSStorage.sol"],
    "TrustedIssuersRegistry.sol": ["@onchain-id/IClaimIssuer.sol", "@openzeppelin/OwnableUpgradeable.sol", "ITrustedIssuersRegistry.sol", "TIRStorage.sol"],

    "IIdentityRegistryStorage.sol": ["IIdentity.sol"],
    "IIdentityRegistry.sol": [
        "ITrustedIssuersRegistry.sol",
        "IClaimTopicsRegistry.sol",
        "IIdentityRegistryStorage.sol",
        "@onchain-id/IClaimIssuer.sol",
        "@onchain-id/IIdentity.sol"
    ],
    "ITrustedIssuersRegistry.sol": ["@onchain-id/IClaimIssuer.sol"],
    "IClaimTopicsRegistry.sol": [],

    "CTRStorage.sol": [],
    "TIRStorage.sol" :[],
    "IRSStorage.sol": [],
    "IRStorage.sol": [],


    "AbstractModule": [
        "IModule.sol"
    ],
    "AbstractModuleUpgradeable.sol" : ["@openzeppelin/Initializable.sol", "@openzeppelin/OwnableUpgradeable.sol",
    "@openzeppelin/UUPSUpgradeable.sol", "IModule.sol"],
    "ConditionalTransferModule.sol" : [
        "IModularCompliance.sol",
        "IToken.sol",
        "AgentRole.sol",
        "AbstractModuleUpgradeable.sol"
    ],
    "CountryAllowModule.sol": ["IModularCompliance.sol","IToken.sol","AbstractModuleUpgraeble.sol"
    ],
    "CountryRestrictModule": [
        "IModularCompliance.sol",
        "IToken.sol",
        "AbstractModuleUpgraeble.sol",
    ],
    "ExchangeMonthlyLimitsModule": [
        "IModularCompliance.sol",
        "IToken.sol",
        "AbstractModuleUpgraeble.sol",
        "AgentRole.sol"
    ],
    "IModule.sol" : [],
    "MaxBalanceModule.sol": [
        "IModularCompliance.sol",
        "IToken.sol",
        "AbstractModuleUpgraeble.sol",
        "@openzeppelin/OwnableUpgradeable.sol"
    ],
    "ModuleProxy.sol":["@openzeppelin/ERC1967Proxy.sol"],
    "SupplyLimitModule.sol": [
        "IModularCompliance.sol",
        "IToken.sol",
        "AbstractModuleUpgraeble.sol",
    ],
    "TimeExchangeLimitsModule.sol": [
        "IModularCompliance.sol",
        "IToken.sol",
        "AbstractModuleUpgraeble.sol",
        "AgentRole.sol"
    ],
    "TimeTransferLimitsModule.sol":[
        "IModularCompliance.sol",
        "IToken.sol",
        "AbstractModuleUpgraeble.sol",
        "AgentRole.sol"        
    ],
    "TransferFeesModule.sol":[
        "IModularCompliance.sol",
        "IToken.sol",
        "AbstractModuleUpgraeble.sol",
        "AgentRole.sol"        
    ],
    "TransferRestrictModule.sol" : ["AbstractModuleUpgradeable.sol"],
    "IModularCompliance.sol": [],
    "MCStorage.sol" : [],
    "ModularCompliance.sol": [
        "@openzeppelin/OwnableUpgradeable.sol",
        "IToken.sol",
        "IModularCompliance.sol",
        "MCStorage.sol",
        "IModule.sol",
    ],


    "ApproveTransfer.sol": ["BasicCompliance.sol"],
    "CountryRestrictions.sol": ["BasicCompliance.sol"],
    "CountryWhitelisting.sol": ["BasicCompliance.sol"],
    "DayMonthLimits.sol":["BasicCompliance.sol"],
    "ExchangeMonthlyLimits.sol" : ["BasicCompliance.sol"],
    "MaxBalance.sol": ["BasicCompliance.sol"],
    "SupplyLimit.sol" : ["BasicCompliance.sol"],
    "BasicCompliance.sol" : [
        "AgentRole.sol",
        "ICompliance.sol",
        "IToken.sol"
    ],
    "DefaultCompliance.sol" : ["BasicCompliance.sol"],
    "ICompliance.sol": [],


    "IAFactory.sol": ["TREXImplementationAuthority.sol"],
    "IIAFactory.sol": [],
    "ITREXImplementationAuthority.sol" : [],
    "TREXImplementationAuthority.sol": ["@openzeppelin/Ownable.sol", "ITREXImplementationAuthority.sol", "IToken.sol", "IProxy.sol", "ITREXFactory.sol", "IIAFactory.sol" ],

    "IProxy.sol": [],

    "AbstractProxy.sol": ["IProxy.sol", "ITREXImplementationAuthority.sol", "@openzeppelin/Initializable.sol" ],
    "ClaimTopicsRegistryProxy.sol": ["AbstractProxy.sol"],
    "IdentityRegistryProxy.sol": ["AbstractProxy.sol"],
    "IdentityRegistryStorageProxy.sol": ["AbstractProxy.sol"],
    "ModularComplianceProxy.sol": ["AbstractProxy.sol"],
    "TokenProxy.sol": ["AbstractProxy.sol"],
    "TrustedIssuersRegistryProxy.sol": ["AbstractProxy.sol"],


    "AgentManager.sol": [
        "@onchain-id/IIdentity.sol",
        "IToken.sol",
        "IIdentityRegistry.sol",
        "AgentRoles.sol"
    ],
    "AgentRoles.sol" : [
        "Roles.sol",
        "@openzeppelin/Ownanble.sol"
    ],
    "AgentRolesUpgradeable.sol" : [
        "Roles.sol",
        "@openzeppelin/OwnableUpgradeable.sol"
    ],
    "OwnerManager.sol" : [
        "IToken.sol",
        "IIdentityRegistry.sol"
        "ITrustedIssuersRegistry.sol",
        "IClaimTopicsRegistry.sol",
        "ICompliance.sol",
        "OwnerRoles.sol",
        "AgentRole.sol",
        "@onchain-id/IIdentity.sol",
        "@onchain-id/IClaimIssuer.sol"      
    ],
    "OwnerRoles.sol": ["Roles.sol", "@openzeppelin/Ownable.sol"],
    "OwnerRolesUpgradeable.sol": ["Roles.sol", "@openzeppelin/OwnableUpgradeable.sol"],
    "AgentRole.sol": ["Roles.sol", "@openzeppelin/Ownable.sol"],
    "AgentRoleUpgradeable.sol": ["Roles.sol", "@openzeppelin/OwnableUpgradeable.sol"],
    "Roles.sol" : [],


    "IToken.sol": ["IIdentityRegistry.sol", "IModularCompliance.sol", "@openzeppelin/IERC20.sol"],
    "Token.sol": ["IToken.sol", "TokenStorage.sol", "AgentRoleUpgradeable.sol", "@onchain-id/IIdentity.sol"],
    "TokenStorage.sol": ["IModularCompliance.sol",
    "IIdentityRegistry.sol"]
}
