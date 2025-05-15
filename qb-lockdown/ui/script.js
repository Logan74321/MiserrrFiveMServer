// ui/script.js
$(document).ready(function() {
    // Variables
    let activeTab = 'games';
    let gameData = null;
    let playerStats = null;
    let gangInfo = null;
    let leaderboard = null;
    let playerLoot = [];
    let extractionPoints = {};
    
    // Listen for messages from game
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        switch (data.action) {
            case 'open':
                if (data.type === 'main') {
                    $('#main-menu').show();
                    $('#game-ui').hide();
                    $('#extraction-report').hide();
                } else if (data.type === 'game') {
                    $('#main-menu').hide();
                    $('#game-ui').show();
                    $('#extraction-report').hide();
                    
                    if (data.game) {
                        gameData = data.game;
                        updateGameUI(gameData);
                    }
                    
                    if (data.loot) {
                        playerLoot = data.loot;
                        updateLootUI();
                    }
                    
                    if (data.extractionPoints) {
                        extractionPoints = data.extractionPoints;
                        updateExtractionUI();
                    }
                }
                break;
                
            case 'updateGames':
                if (data.games) {
                    updateGamesTab(data.games);
                }
                break;
                
            case 'updateStats':
                if (data.stats) {
                    playerStats = data.stats;
                    updateStatsTab();
                }
                break;
                
            case 'updateGang':
                if (data.gang) {
                    gangInfo = data.gang;
                    updateGangTab();
                } else {
                    // No gang
                    $('#no-gang-container').show();
                    $('#gang-container').hide();
                }
                break;
                
            case 'updateLeaderboard':
                if (data.leaderboard) {
                    leaderboard = data.leaderboard;
                    updateLeaderboardTab();
                }
                break;
                
            case 'showGameInfo':
                if (data.game) {
                    gameData = data.game;
                }
                if (data.zone) {
                    $('#game-zone').text(data.zone.label);
                }
                break;
                
            case 'gameStarted':
                if (data.game) {
                    gameData = data.game;
                    updateGameUI(gameData);
                }
                break;
                
            case 'updateTimer':
                if (data.timeRemaining) {
                    updateGameTimer(data.timeRemaining);
                }
                break;
                
            case 'updateLoot':
                if (data.loot) {
                    playerLoot = data.loot;
                    updateLootUI();
                }
                break;
                
            case 'updateExtractions':
                if (data.extractionPoints) {
                    extractionPoints = data.extractionPoints;
                    updateExtractionUI();
                }
                break;
                
            case 'showExtractionReport':
                showExtractionReport(data.message, data.value);
                break;
                
            case 'endGame':
                $('#game-ui').hide();
                break;
                
            case 'showAnnouncement':
                showAnnouncement(data.zone, data.label);
                break;
        }
    });
    
    // Tab switching
    $('.tab').on('click', function() {
        const tab = $(this).data('tab');
        
        $('.tab').removeClass('active');
        $(this).addClass('active');
        
        $('.tab-content').hide();
        $(`#${tab}-tab`).show();
        
        activeTab = tab;
    });
    
    // Close button
    $('.btn-close').on('click', function() {
        $.post('https://qb-lockdown/close', {});
    });
    
    // Join game
    $(document).on('click', '.join-game-btn', function() {
        const gameId = $(this).data('id');
        $.post('https://qb-lockdown/joinGame', JSON.stringify({
            gameId: gameId
        }));
    });
    
    // Create gang form
    $('.create-gang-btn').on('click', function() {
        $('.gang-info').hide();
        $('.create-gang-form').show();
    });
    
    $('.btn-cancel').on('click', function() {
        $('.create-gang-form').hide();
        $('.gang-info').show();
    });
    
    $('.btn-create').on('click', function() {
        const name = $('#gang-name').val();
        const color = $('#gang-color').val();
        const emblem = $('#gang-emblem').val();
        
        if (!name || name.length < 3) {
            // Show error
            return;
        }
        
        $.post('https://qb-lockdown/createGang', JSON.stringify({
            name: name,
            color: color,
            emblem: emblem
        }));
        
        $('.create-gang-form').hide();
        $('.gang-info').show();
    });
    
    // Invite player to gang
    $('.invite-btn').on('click', function() {
        $.post('https://qb-lockdown/showPlayerList', {});
    });
    
    // Leave gang
    $('.leave-btn').on('click', function() {
        $.post('https://qb-lockdown/leaveGang', {});
    });
    
    // Close extraction report
    $('.btn-close-report').on('click', function() {
        $('#extraction-report').hide();
    });
    
    // Functions
    function updateGamesTab(games) {
        const gameList = $('.game-list');
        gameList.empty();
        
        if (Object.keys(games).length === 0) {
            gameList.html('<p>No active Lockdown Protocols at the moment.</p>');
            return;
        }
        
        for (const [id, game] of Object.entries(games)) {
            const stateClass = game.state === 'active' ? 'active' : 'waiting';
            const stateText = game.state === 'active' ? 'Active' : 'Waiting';
            
            const gameCard = `
                <div class="game-card ${stateClass}">
                    <div class="game-card-header">
                        <div class="game-zone-name">${game.label}</div>
                        <div class="game-state ${stateClass}">${stateText}</div>
                    </div>
                    <div class="game-card-content">
                        <div class="game-info-item">
                            <span>Players:</span>
                            <span>${game.players}/${game.maxPlayers}</span>
                        </div>
                        <div class="game-info-item">
                            <span>Time Remaining:</span>
                            <span>${formatTime(game.timeRemaining)}</span>
                        </div>
                    </div>
                    <div class="game-card-footer">
                        <button class="btn join-game-btn" data-id="${id}">JOIN</button>
                    </div>
                </div>
            `;
            
            gameList.append(gameCard);
        }
    }
    
    function updateStatsTab() {
        if (!playerStats) return;
        
        $('#extractions').text(playerStats.extractions || 0);
        $('#deaths').text(playerStats.deaths || 0);
        $('#kills').text(playerStats.kills || 0);
        $('#total-value').text('$' + (playerStats.total_value || 0).toLocaleString());
        $('#highest-streak').text(playerStats.highest_streak || 0);
        $('#contracts').text(playerStats.contracts_completed || 0);
        
        // Update rank
        let rankName = 'Runner';
        let nextRankExtractions = 10;
        let progress = 0;
        
        if (playerStats.extractions >= 50) {
            rankName = 'Kingpin';
            nextRankExtractions = 50;
            progress = 100;
        } else if (playerStats.extractions >= 25) {
            rankName = 'Shot Caller';
            nextRankExtractions = 50;
            progress = ((playerStats.extractions - 25) / 25) * 100;
        } else if (playerStats.extractions >= 10) {
            rankName = 'Enforcer';
            nextRankExtractions = 25;
            progress = ((playerStats.extractions - 10) / 15) * 100;
        } else {
            progress = (playerStats.extractions / 10) * 100;
        }
        
        $('#rank-name').text(rankName);
        $('#current-extractions').text(playerStats.extractions || 0);
        $('#needed-extractions').text(nextRankExtractions);
        $('#rank-progress-bar').css('width', progress + '%');
    }
    
    function updateGangTab() {
        if (!gangInfo) {
            $('#no-gang-container').show();
            $('#gang-container').hide();
            return;
        }
        
        $('#no-gang-container').hide();
        $('#gang-container').show();
        
        // Set gang name and color
        $('#gang-display-name').text(gangInfo.name);
        $('#gang-display-name').css('color', gangInfo.color);
        
        // Set emblem
        $('#gang-emblem-display').html(`<i class="fas fa-${gangInfo.emblem}"></i>`);
        $('#gang-emblem-display').css('color', gangInfo.color);
        
        // Set rank
        let rankName = 'Prospect';
        if (gangInfo.rank === 3) {
            rankName = 'OG (Leader)';
        } else if (gangInfo.rank === 2) {
            rankName = 'Shooter';
        }
        
        $('#gang-rank-display').text('Rank: ' + rankName);
        
        // Update member list if available
        if (gangInfo.members) {
            updateGangMembers(gangInfo.members);
        }
    }
    
    function updateGangMembers(members) {
        const memberList = $('#member-list');
        memberList.empty();
        
        for (const member of members) {
            let rankName = 'Prospect';
            if (member.rank === 3) {
                rankName = 'OG (Leader)';
            } else if (member.rank === 2) {
                rankName = 'Shooter';
            }
            
            const memberCard = `
                <div class="member-card">
                    <div class="member-name">${member.name}</div>
                    <div class="member-rank">${rankName}</div>
                </div>
            `;
            
            memberList.append(memberCard);
        }
    }
    
    function updateLeaderboardTab() {
        if (!leaderboard) return;
        
        const leaderboardList = $('#leaderboard-list');
        leaderboardList.empty();
        
        for (const entry of leaderboard) {
            const leaderboardItem = `
                <div class="leaderboard-item">
                    <div class="lb-rank">${entry.rank}</div>
                    <div class="lb-name">${entry.name}</div>
                    <div class="lb-extractions">${entry.extractions}</div>
                    <div class="lb-kills">${entry.kills}</div>
                    <div class="lb-value">$${entry.value.toLocaleString()}</div>
                </div>
            `;
            
            leaderboardList.append(leaderboardItem);
        }
    }
    
    function updateGameUI(game) {
        if (!game) return;
        
        // Update zone name
        if (game.zone && Config.Zones[game.zone]) {
            $('#game-zone').text(Config.Zones[game.zone].label);
        }
        
        // Update timer
        if (game.endTime) {
            updateGameTimer(game.endTime - Math.floor(Date.now() / 1000));
        }
        
        // Update wanted level
        updateWantedLevel(game.wantedLevel || 1);
    }
    
    function updateGameTimer(timeRemaining) {
        const minutes = Math.floor(timeRemaining / 60);
        const seconds = timeRemaining % 60;
        
        $('#game-timer').text(
            (minutes < 10 ? '0' : '') + minutes + ':' + 
            (seconds < 10 ? '0' : '') + seconds
        );
    }
    
    function updateWantedLevel(level) {
        const stars = $('#wanted-level').find('i');
        
        stars.each(function(index) {
            if (index < level) {
                $(this).removeClass('empty');
            } else {
                $(this).addClass('empty');
            }
        });
    }
    
    function updateLootUI() {
        const lootContainer = $('#loot-items');
        lootContainer.empty();
        
        let totalValue = 0;
        
        for (const item of playerLoot) {
            let itemName = item.name;
            let itemValue = 0;
            
            if (item.type === 'cash') {
                itemName = 'Cash';
                itemValue = item.amount;
                totalValue += item.amount;
            } else {
                // Get item info from config
                // For now, just use placeholder values
                itemValue = item.amount * 1000; // Placeholder
                totalValue += itemValue;
            }
            
            const lootItem = `
                <div class="loot-item">
                    <div class="loot-item-name">${itemName} x${item.amount}</div>
                    <div class="loot-item-value">$${itemValue.toLocaleString()}</div>
                </div>
            `;
            
            lootContainer.append(lootItem);
        }
        
        $('#loot-total-value').text('$' + totalValue.toLocaleString());
    }
    
    function updateExtractionUI() {
        if (Object.keys(extractionPoints).length === 0) {
            $('#extraction-info').hide();
            return;
        }
        
        $('#extraction-info').show();
        const extractionList = $('#extraction-points');
        extractionList.empty();
        
        for (const [id, point] of Object.entries(extractionPoints)) {
            let icon = 'fa-truck';
            if (point.type === 'boat') {
                icon = 'fa-ship';
            } else if (point.type === 'heli') {
                icon = 'fa-helicopter';
            }
            
            const extractionPoint = `
                <div class="extraction-point">
                    <div class="extraction-point-icon">
                        <i class="fas ${icon}"></i>
                    </div>
                    <div class="extraction-point-label">${point.label}</div>
                </div>
            `;
            
            extractionList.append(extractionPoint);
        }
    }
    
    function showExtractionReport(message, totalValue) {
        $('#main-menu').hide();
        $('#game-ui').hide();
        $('#extraction-report').show();
        
        const reportContent = $('#report-content');
        reportContent.empty();
        
        // Parse the message
        const lines = message.split('\n');
        
        for (let i = 0; i < lines.length - 2; i++) {
            if (lines[i].trim() === '') continue;
            
            const parts = lines[i].split(':');
            if (parts.length === 2) {
                const reportItem = `
                    <div class="report-item">
                        <div class="report-item-name">${parts[0].trim()}</div>
                        <div class="report-item-value">${parts[1].trim()}</div>
                    </div>
                `;
                
                reportContent.append(reportItem);
            }
        }
        
        // Add total
        const reportTotal = `
            <div class="report-total">
                <div>TOTAL VALUE:</div>
                <div>$${totalValue.toLocaleString()}</div>
            </div>
        `;
        
        reportContent.append(reportTotal);
    }
    
    function showAnnouncement(zone, label) {
        $('#game-announcement').show();
        $('#announcement-zone').text(label);
        
        setTimeout(function() {
            $('#game-announcement').fadeOut(1000);
        }, 10000);
    }
    
    function formatTime(seconds) {
        const minutes = Math.floor(seconds / 60);
        const secs = seconds % 60;
        
        return (minutes < 10 ? '0' : '') + minutes + ':' + 
               (secs < 10 ? '0' : '') + secs;
    }
    
    // Initialization
    $('#games-tab').show();
});