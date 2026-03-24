import groovy.json.JsonSlurper
import org.sonatype.nexus.capability.CapabilityReference
import org.sonatype.nexus.capability.CapabilityType
import org.sonatype.nexus.internal.capability.DefaultCapabilityReference
import org.sonatype.nexus.internal.capability.DefaultCapabilityRegistry

parsed_args = new JsonSlurper().parseText(args)

if (parsed_args.capability_properties.containsKey('headerEnabled')) {
    parsed_args.capability_properties['headerEnabled'] = parsed_args.capability_properties['headerEnabled'].toString()
}
if (parsed_args.capability_properties.containsKey('footerEnabled')) {
    parsed_args.capability_properties['footerEnabled'] = parsed_args.capability_properties['footerEnabled'].toString()
}

def capabilityRegistry = container.lookup(DefaultCapabilityRegistry.class.getName())
def capabilityType = CapabilityType.capabilityType(parsed_args.capability_typeId)

DefaultCapabilityReference existing = capabilityRegistry.all.find { CapabilityReference capabilityReference ->
    capabilityReference.context().descriptor().type() == capabilityType
}

try {
    if (existing) {
        log.info(parsed_args.typeId + ' capability updated to: {}',
                capabilityRegistry.update(existing.id(), Boolean.valueOf(parsed_args.get('capability_enabled', true)), existing.notes(), parsed_args.capability_properties).toString()
        )
    }
    else {
        log.info(parsed_args.typeId + ' capability created as: {}', capabilityRegistry.
                add(capabilityType, Boolean.valueOf(parsed_args.get('capability_enabled', true)), 'configured through api', parsed_args.capability_properties).toString()
        )
    }
}
catch (NullPointerException ignored) {
    return groovy.json.JsonOutput.toJson([
            changed: false,
            skipped: true,
            status : 'unsupported_capability',
            typeId : parsed_args.capability_typeId
    ])
}
