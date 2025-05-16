$(function () {
    $("body").hide();
    $('#energy').hide();
    $('#extraction').hide();
    
    // Event listener for messages from the client-side script
    window.addEventListener('message', function(event) {
        let text = document.getElementById("text")
        let kills = document.getElementById("kills")
        let winningsound = document.getElementById("winningsound")
        let lootsound = document.getElementById("lootsound")
        let players = document.getElementById("players")
        let zone = document.getElementById("zone")
        let tierText = document.getElementById("winstop")
        let energyBar = document.getElementById("myBar");
        let extractionBar = document.getElementById("extractionBar");
        
        var item = event.data;
        
        // Text notifications (e.g., "Victory", "Eliminated")
        if (item.type === "text") {
            $("body").fadeIn();
            $("#text").fadeIn();
            if (item.text == 'Victory' || item.text == 'Extraction Complete') {
                winningsound.load()
                winningsound.play();
                winningsound.volume = 0.28;
                $('#energy').hide();
                $('#extraction').hide();
            }
            text.innerText = item.text
            setTimeout(function() {
                $("#text").fadeOut(); 
                winningsound.pause();
            }, 4800);
        }  
        
        // Energy bar display
        if (item.type === 'energy') {
            $('#energy').show();
            energyBar.style.width = item.level + '%';
        }
        
        // Extraction progress display
        if (item.type === 'extraction') {
            $('#extraction').show();
            extractionBar.style.width = item.progress + '%';
            if (item.progress >= 100) {
                setTimeout(function() {
                    $('#extraction').fadeOut();
                }, 1000);
            }
        }
        
        // Lobby screen display
        if (item.type == 'lobbyscreen') {
            $('#energy').hide();
            $('#extraction').hide();
            $("body").fadeIn();
            $('#leaderboarddiv').hide();
            $('#gangdiv').hide();
            $('#contractsdiv').hide();
            $('#careerdiv').hide();
            $('#hud').hide();
            $('#container').hide();
            $('#lobbyscreen').show();
            $('#gameselector').hide();
            
            // Update player tier display in lobby
            if (item.stats) {
                const tierName = item.stats.tier_name || "Runner";
                tierText.innerText = 'TIER: ' + tierName.toUpperCase();
                
                // Update stats
                document.getElementById("mplayedct").innerHTML = item.stats.extractions || 0;
                document.getElementById("tierct").innerHTML = tierName;
                document.getElementById("killst").innerHTML = item.stats.kills || 0;
                document.getElementById("deathsct").innerHTML = item.stats.deaths || 0;
                document.getElementById("valuect").innerHTML = '$' + (item.stats.extracted_value || 0).toLocaleString();
                document.getElementById("contractsct").innerHTML = item.stats.contracts_completed || 0;
            } else {
                tierText.innerText = 'TIER: RUNNER';
            }
        }
        
        // In-game UI display
        if (item.type === "ui") {
            $('#lobbyscreen').hide();
            $("body").fadeIn();
            $('#hud').fadeIn();
            $('#container').fadeIn();
            
            // Set zone name
            if (item.zone) {
                zone.innerText = 'ZONE: ' + item.zone;
            }
            
            // Set kills count
            if (item.Kills == undefined) {
                kills.innerText = 'KILLS: 0';
            } else {
                kills.innerText = 'KILLS: ' + item.Kills;
            }
            
            // Set players alive count
            if (item.Playersingame == undefined) {
                players.innerText = 'ALIVE: 0/12';
            } else {
                players.innerText = 'ALIVE: ' + item.Playersingame + '/12';
            }
        }  
        
        // Hide UI
        if (item.type === "uihide") {
            $("body").fadeOut();
            $('#energy').hide();
            $('#extraction').hide();
        }   
        
        // Play loot sound
        if (item.type === "loot") {
            lootsound.play();
        }   
         
        // Leaderboard data
        if (item.type === "leaderboardData") {
            $('#namep').empty();
            $('#extractionsp').empty();
            $('#valuep').empty();
            $('#topnumberid').empty();
            
            if (item.data && item.data.length > 0) {
                item.data.forEach((player, index) => {
                    // Add player data to leaderboard
                    const rankItem = $('<div>')
                        .addClass('leaderboardItem')
                        .addClass('leaderboardRank')
                        .text((index + 1) + '.');
                    
                    const nameItem = $('<div>')
                        .addClass('leaderboardItem')
                        .text(player.name);
                    
                    const extractionsItem = $('<div>')
                        .addClass('leaderboardItem')
                        .text(player.extractions);
                    
                    const valueItem = $('<div>')
                        .addClass('leaderboardItem')
                        .text('$' + player.extracted_value.toLocaleString());
                    
                    $('#topnumberid').append(rankItem);
                    $('#namep').append(nameItem);
                    $('#extractionsp').append(extractionsItem);
                    $('#valuep').append(valueItem);
                });
            } else {
                const noDataMsg = $('<div>')
                    .addClass('leaderboardItem')
                    .text('No data available');
                
                $('#topnumberid').append(noDataMsg.clone());
                $('#namep').append(noDataMsg.clone());
                $('#extractionsp').append(noDataMsg.clone());
                $('#valuep').append(noDataMsg.clone());
            }
        }
        
        // Gang data
        if (item.type === "gangData") {
            $('#gangcontent').empty();
            $('#gangListItems').empty();
            
            if (item.data.in_gang) {
                // Display current gang info
                $('#gangtitle').text('YOUR GANG');
                
                const gangInfo = $('<div>').addClass('gangInfo');
                const gangName = $('<div>')
                    .addClass('gangName')
                    .text(item.data.name);
                
                const gangColor = $('<div>')
                    .addClass('gangColor')
                    .text('Color: ')
                    .append($('<span>')
                        .css('color', item.data.color)
                        .text('■'));
                
                gangInfo.append(gangName).append(gangColor);
                
                // Members list
                const gangMembers = $('<div>').addClass('gangMembers');
                const membersTitle = $('<h3>').text('MEMBERS');
                gangMembers.append(membersTitle);
                
                item.data.members.forEach(member => {
                    const memberItem = $('<div>').addClass('gangMember');
                    const memberName = $('<div>').addClass('memberName').text(member.name);
                    
                    let rankName = "Prospect";
                    if (member.rank === 2) rankName = "Shooter";
                    if (member.rank === 3) rankName = "OG";
                    
                    const memberRank = $('<div>').addClass('memberRank').text(rankName);
                    memberItem.append(memberName).append(memberRank);
                    gangMembers.append(memberItem);
                });
                
                $('#gangcontent').append(gangInfo).append(gangMembers);
                
                // Show leave button, hide create and join buttons
                $('#createGangBtn').hide();
                $('#gangNameInput').hide();
                $('#gangColorInput').hide();
                $('#leaveGangBtn').show();
                $('#gangList').hide();
                
            } else {
                // Show create gang form and available gangs
                $('#gangtitle').text('CREATE OR JOIN A GANG');
                
                const createForm = $('<div>').addClass('createGangForm');
                const formTitle = $('<h3>').text('CREATE NEW GANG');
                createForm.append(formTitle);
                
                $('#gangcontent').append(createForm);
                
                // Show create buttons, hide leave button
                $('#createGangBtn').show();
                $('#gangNameInput').show();
                $('#gangColorInput').show();
                $('#leaveGangBtn').hide();
                $('#gangList').show();
                
                // List available gangs
                if (item.data.gangs && item.data.gangs.length > 0) {
                    item.data.gangs.forEach(gang => {
                        const gangItem = $('<div>').addClass('gangListItem');
                        const gangName = $('<div>').addClass('gangListName').text(gang.name);
                        
                        const joinBtn = $('<button>')
                            .addClass('gangListJoin')
                            .text('JOIN')
                            .attr('data-gang-id', gang.id)
                            .click(function() {
                                joinGang(gang.id);
                            });
                        
                        gangItem.append(gangName).append(joinBtn);
                        $('#gangListItems').append(gangItem);
                    });
                } else {
                    $('#gangListItems').append($('<div>').addClass('gangListItem').text('No gangs available'));
                }
            }
        }
        
        // Contracts data
        if (item.type === "contractsData") {
            $('#contractsList').empty();
            
            if (item.data && item.data.length > 0) {
                item.data.forEach(contract => {
                    const contractItem = $('<div>').addClass('contractItem');
                    
                    const contractHeader = $('<div>').addClass('contractHeader');
                    const contractName = $('<div>').addClass('contractName').text(contract.name);
                    const contractReward = $('<div>').addClass('contractReward').text('$' + contract.reward_cash + ' + ' + contract.reward_xp + ' XP');
                    contractHeader.append(contractName).append(contractReward);
                    
                    const contractDesc = $('<div>').addClass('contractDescription').text(contract.description);
                    
                    const acceptBtn = $('<button>')
                        .addClass('contractAccept')
                        .text('ACCEPT')
                        .attr('data-contract-id', contract.id)
                        .click(function() {
                            acceptContract(contract.id);
                        });
                    
                    contractItem.append(contractHeader).append(contractDesc).append(acceptBtn);
                    $('#contractsList').append(contractItem);
                });
            } else {
                $('#contractsList').append($('<div>').addClass('contractItem').text('No contracts available'));
            }
        }
    });   
});

// Navigation menu functions
function play(){
    $('#leaderboarddiv').hide();
    $('#careerdiv').hide();
    $('#gangdiv').hide();
    $('#contractsdiv').hide();
    $('#gameselector').fadeIn();
}

function joinSolo(){
    $.post(`https://${GetParentResourceName()}/joinLockdown`, {
        type: "solo"
    });
}

function joinGang(){
    // Get player's gang id from UI or cached data
    const gangId = currentGangId || null; // This should be set when loading gang data
    
    $.post(`https://${GetParentResourceName()}/joinLockdown`, {
        type: "gang",
        gangId: gangId
    });
}

function leave(){
    $("body").hide();
    $.post(`https://${GetParentResourceName()}/leaveLobby`);
    $('#energy').hide();
}

function board(){
    // Request leaderboard data
    $.post(`https://${GetParentResourceName()}/getLeaderboard`, {}, function(data) {
        // Data will be handled by the message event listener
    });
    
    $('#gameselector').hide();
    $('#careerdiv').hide();
    $('#gangdiv').hide();
    $('#contractsdiv').hide();
    $('#leaderboarddiv').fadeIn();
}

function career(){
    // Request player stats
    $.post(`https://${GetParentResourceName()}/getPlayerStats`, {}, function(data) {
        // Data will be handled by the message event listener
    });
    
    $('#gameselector').hide();
    $('#leaderboarddiv').hide();
    $('#gangdiv').hide();
    $('#contractsdiv').hide();
    $('#careerdiv').fadeIn();
}

function gang(){
    // Request gang data
    $.post(`https://${GetParentResourceName()}/getGangData`, {}, function(data) {
        // Data will be handled by the message event listener
    });
    
    $('#gameselector').hide();
    $('#leaderboarddiv').hide();
    $('#careerdiv').hide();
    $('#contractsdiv').hide();
    $('#gangdiv').fadeIn();
}

function contracts(){
    // Request contracts data
    $.post(`https://${GetParentResourceName()}/getContracts`, {}, function(data) {
        // Data will be handled by the message event listener
    });
    
    $('#gameselector').hide();
    $('#leaderboarddiv').hide();
    $('#careerdiv').hide();
    $('#gangdiv').hide();
    $('#contractsdiv').fadeIn();
}

// Gang system functions
let currentGangId = null;

function createGang() {
    const gangName = $('#gangNameInput').val();
    const gangColor = $('#gangColorInput').val();
    
    if (!gangName || gangName.trim() === '') {
        alert('Please enter a gang name');
        return;
    }
    
    $.post(`https://${GetParentResourceName()}/createGang`, {
        name: gangName,
        color: gangColor,
        emblem: 0 // Default emblem ID
    }, function(response) {
        if (response.success) {
            alert('Gang created successfully!');
            gang(); // Refresh gang view
        } else {
            alert('Failed to create gang: ' + response.message);
        }
    });
}

function joinGang(gangId) {
    $.post(`https://${GetParentResourceName()}/joinGang`, {
        gangId: gangId
    }, function(response) {
        if (response.success) {
            alert('Successfully joined gang!');
            currentGangId = gangId;
            gang(); // Refresh gang view
        } else {
            alert('Failed to join gang: ' + response.message);
        }
    });
}

function leaveGang() {
    $.post(`https://${GetParentResourceName()}/leaveGang`, {}, function(response) {
        if (response.success) {
            alert('Successfully left the gang!');
            currentGangId = null;
            gang(); // Refresh gang view
        } else {
            alert('Failed to leave gang: ' + response.message);
        }
    });
}

// Contract system functions
function acceptContract(contractId) {
    $.post(`https://${GetParentResourceName()}/acceptContract`, {
        contractId: contractId
    }, function(response) {
        if (response.success) {
            alert('Contract accepted! Complete it during your next Lockdown mission.');
            contracts(); // Refresh contracts view
        } else {
            alert('Failed to accept contract.');
        }
    });
}